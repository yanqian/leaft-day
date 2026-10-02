import XCTest
@testable import SwipeGo

@MainActor final class PendingAdvanceTests: XCTestCase {
    private func url() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("Intent.store")
    }
    private func assets() -> [PhotoAssetSnapshot] { ["a", "b", "c", "d"].map { FavoriteTests.snapshot($0) } }
    private func snapshot(_ assets: [PhotoAssetSnapshot]) -> LibrarySnapshot { .init(permission: .full, assets: assets, sharedLibraryMembershipVerified: false) }
    private func segment(_ ids: [String]) -> ReviewSegment { .init(assetIDs: ids, start: nil, end: nil) }
    func testSavedMarkSkipsPendingAndUndoRestoresOriginalOrder() async throws {
        let store = try LocalStateStore(url: url()), all = assets()
        let reader = FavoriteTests.Writer(all), review = ReviewSession(store: store)
        let pending = PendingCoordinator(store: store, reader: reader)
        review.updateLibrary(snapshot(all)); try await review.start(segment(["a", "b", "c"]))
        try await pending.mark("b"); try await pending.mark("a"); review.updatePending(pending.items)
        let session = review.state!.id
        try await review.advanceAfterPending(assetID: "a", sessionID: session)
        XCTAssertEqual(review.currentID, "c"); XCTAssertEqual(review.remainingCount, 0)
        XCTAssertEqual(review.state?.assetIDs, ["a", "b", "c"])
        // A late duplicate callback cannot advance the next asset.
        try await review.advanceAfterPending(assetID: "a", sessionID: session)
        XCTAssertEqual(review.currentID, "c")
        try await pending.undo(); review.updatePending(pending.items); try await review.returnToUnmarked("a")
        XCTAssertEqual(review.currentID, "a"); XCTAssertEqual(review.remainingCount, 1)
        try await review.move(by: 1); XCTAssertEqual(review.currentID, "c")
        try await review.move(by: -1); XCTAssertEqual(review.currentID, "a")
        let writes = await reader.calls; XCTAssertTrue(writes.isEmpty)
    }
    func testLastItemCompletesDurablyAndUndoReturnsThePhoto() async throws {
        let path = try url(), store = try LocalStateStore(url: path), all = assets()
        let pending = PendingCoordinator(store: store, reader: FavoriteTests.Writer(all)), review = ReviewSession(store: store)
        review.updateLibrary(snapshot(all)); try await review.start(segment(["a"]))
        try await pending.mark("a"); review.updatePending(pending.items)
        try await review.advanceAfterPending(assetID: "a", sessionID: review.state!.id)
        XCTAssertEqual(review.current, .completed); XCTAssertNil(review.currentID); XCTAssertEqual(review.remainingCount, 0)
        let reopened = ReviewSession(store: try LocalStateStore(url: path)); reopened.updateLibrary(snapshot(all)); try await reopened.restore()
        XCTAssertTrue(reopened.isComplete); XCTAssertEqual(reopened.current, .completed)
        try await pending.undo(); reopened.updatePending(pending.items); try await reopened.returnToUnmarked("a")
        XCTAssertEqual(reopened.currentID, "a"); XCTAssertEqual(reopened.remainingCount, 0)
    }
    func testFailedMarkLeavesPhotoAndFailedPositionKeepsSavedMarkForRetry() async throws {
        let path = try url(), store = try LocalStateStore(url: path), all = assets()
        let review = ReviewSession(store: store); review.updateLibrary(snapshot(all)); try await review.start(segment(["a", "b"]))
        let failingMark = PendingCoordinator(store: try LocalStateStore(url: path, allowsSave: false), reader: FavoriteTests.Writer(all))
        do { try await failingMark.mark("a"); XCTFail() } catch { }
        review.updatePending(failingMark.items)
        XCTAssertEqual(review.currentID, "a"); XCTAssertEqual(review.remainingCount, 1)
        let pending = PendingCoordinator(store: store, reader: FavoriteTests.Writer(all)); try await pending.mark("a")
        let readOnly = ReviewSession(store: try LocalStateStore(url: path, allowsSave: false)); readOnly.updateLibrary(snapshot(all)); try await readOnly.restore()
        let before = readOnly.state
        do { try await readOnly.advanceAfterPending(assetID: "a", sessionID: before!.id); XCTFail() } catch { }
        XCTAssertEqual(readOnly.state, before)
        let durable = try await store.pending(); XCTAssertEqual(durable.map(\.assetID), ["a"])
        let restored = ReviewSession(store: store); restored.updateLibrary(snapshot(all)); try await restored.restore(); try await restored.resumeAvoidingPending()
        XCTAssertEqual(restored.currentID, "b"); XCTAssertEqual(restored.remainingCount, 0)
    }
    func testContinuousExtensionSkipsPendingAndScopeWhileAnniversaryCompletes() async throws {
        let all = assets(), store = try LocalStateStore(url: url())
        let pending = PendingCoordinator(store: store, reader: FavoriteTests.Writer(all))
        try await pending.mark("b")
        let review = ReviewSession(store: store, assetScope: ["a", "b", "c"])
        review.updateLibrary(snapshot(all)); review.updatePending(pending.items)
        try await review.start(segment(["a"]), mode: .continuous)
        try await pending.mark("a"); review.updatePending(pending.items)
        try await review.advanceAfterPending(assetID: "a", sessionID: review.state!.id)
        XCTAssertEqual(review.currentID, "c"); XCTAssertEqual(review.state?.assetIDs, ["a", "c"])
        XCTAssertFalse(review.canGoForward)
        try await review.start(segment(["c"]), mode: .anniversary)
        try await pending.mark("c"); review.updatePending(pending.items)
        try await review.advanceAfterPending(assetID: "c", sessionID: review.state!.id)
        XCTAssertTrue(review.isComplete); XCTAssertEqual(review.state?.assetIDs, ["c"])
        XCTAssertNil(review.nearbySegment, "Never offer marked or out-of-scope assets")
    }
    func testOldPayloadAndAllMarkedSessionAreSafe() async throws {
        let old = SessionState(id: UUID(), assetIDs: ["a"], cursor: 0, updatedAt: .now)
        let decoded = try JSONDecoder().decode(SessionState.self, from: JSONEncoder().encode(old))
        XCTAssertNil(decoded.completed)
        let store = try LocalStateStore(url: url()), all = assets(), review = ReviewSession(store: store)
        let pending = PendingCoordinator(store: store, reader: FavoriteTests.Writer(all)); try await pending.mark("a")
        review.updateLibrary(snapshot(all)); review.updatePending(pending.items); try await review.start(segment(["a"]))
        XCTAssertTrue(review.isComplete); XCTAssertNil(review.currentID); XCTAssertEqual(review.remainingCount, 0)
    }
    func testUndoPositionFailureRecoversFromDiskWithoutRepeatingUnmark() async throws {
        let path = try url(), store = try LocalStateStore(url: path), all = assets()
        let pending = PendingCoordinator(store: store, reader: FavoriteTests.Writer(all))
        let review = ReviewSession(store: store); review.updateLibrary(snapshot(all)); try await review.start(segment(["a"]))
        try await pending.mark("a"); review.updatePending(pending.items)
        try await review.advanceAfterPending(assetID: "a", sessionID: review.state!.id)
        let failingPosition = ReviewSession(store: try LocalStateStore(url: path, allowsSave: false))
        failingPosition.updateLibrary(snapshot(all)); try await failingPosition.restore()
        try await pending.undo(); failingPosition.updatePending(pending.items)
        do { try await failingPosition.returnToUnmarked("a"); XCTFail() } catch { }
        XCTAssertTrue(failingPosition.isComplete)
        let persistedPending = try await store.pending(); XCTAssertTrue(persistedPending.isEmpty)
        let reopened = ReviewSession(store: try LocalStateStore(url: path)); reopened.updateLibrary(snapshot(all)); try await reopened.restore()
        XCTAssertFalse(reopened.isComplete); XCTAssertEqual(reopened.currentID, "a"); XCTAssertEqual(reopened.remainingCount, 0)
        let disk = try await store.latestSession(); XCTAssertEqual(disk?.completed, false)
    }
    func testCompletedSessionCanNavigateBackAndNewForwardContent() async throws {
        let store = try LocalStateStore(url: url()), all = assets(), review = ReviewSession(store: store)
        let pending = PendingCoordinator(store: store, reader: FavoriteTests.Writer(all))
        review.updateLibrary(snapshot(Array(all.prefix(2))))
        try await review.start(segment(["a", "b"]), mode: .continuous); try await review.move(by: 1)
        try await pending.mark("b"); review.updatePending(pending.items)
        try await review.advanceAfterPending(assetID: "b", sessionID: review.state!.id)
        XCTAssertTrue(review.isComplete); XCTAssertTrue(review.canGoBack)
        try await review.move(by: -1); XCTAssertEqual(review.currentID, "a")
        try await review.start(segment(["b"]), mode: .continuous); XCTAssertTrue(review.isComplete)
        review.updateLibrary(snapshot(Array(all.prefix(3))))
        XCTAssertTrue(review.canGoForward); try await review.move(by: 1)
        XCTAssertEqual(review.currentID, "c"); XCTAssertFalse(review.isComplete)
    }

    func testNearbyUndoRestoresOriginalSessionAndRejectsUnavailableTargets() async throws {
        let path = try url(), store = try LocalStateStore(url: path), all = assets()
        let fault = PendingFaultTestStore(base: store, fault: .position)
        let review = ReviewSession(store: fault, assetScope: ["a", "b", "c"])
        let pending = PendingCoordinator(store: store, reader: FavoriteTests.Writer(all))
        review.updateLibrary(snapshot(all)); try await review.start(segment(["a"]), mode: .anniversary)
        let origin = review.state!.id
        try await pending.mark("a"); review.updatePending(pending.items)
        try await review.advanceAfterPending(assetID: "a", sessionID: origin)
        XCTAssertTrue(review.isComplete)
        try await review.exploreNearby()
        XCTAssertNotEqual(review.state?.id, origin); XCTAssertFalse(review.state!.assetIDs.contains("a"))
        let nearby = review.state
        try await pending.undo(); review.updatePending(pending.items)
        review.updateLibrary(snapshot(Array(all.dropFirst())))
        do { try await review.returnToUnmarked("a", sessionID: origin); XCTFail("Unavailable target must not silently succeed") } catch { }
        XCTAssertEqual(review.state, nearby)
        review.updateLibrary(snapshot(all))
        fault.armOnce()
        do { try await review.returnToUnmarked("a", sessionID: origin); XCTFail("Position failure must retain the new session for explicit retry") } catch { }
        XCTAssertEqual(review.state, nearby)
        try await review.returnToUnmarked("a", sessionID: origin)
        XCTAssertEqual(review.currentID, "a"); XCTAssertEqual(review.state?.id, origin)
        XCTAssertEqual(review.state?.assetIDs, ["a"]); XCTAssertEqual(review.state?.mode, .anniversary)
        XCTAssertEqual(review.remainingCount, 0)
        let reopened = ReviewSession(store: try LocalStateStore(url: path)); reopened.updateLibrary(snapshot(all)); try await reopened.restore()
        XCTAssertEqual(reopened.currentID, "a"); XCTAssertEqual(reopened.state?.id, origin)
        do { try await review.returnToUnmarked("missing", sessionID: UUID()); XCTFail("Missing original session must fail explicitly") } catch { }
    }

}
