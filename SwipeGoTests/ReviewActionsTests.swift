import XCTest
@testable import SwipeGo

@MainActor final class ReviewActionsTests: XCTestCase {
    private struct Context {
        let store: LocalStateStore
        let review: ReviewSession
        let pending: PendingCoordinator
        let favorites: FavoriteCoordinator
        let writer: FavoriteTests.Writer
        let actions: ReviewActions
        let fault: PendingFaultTestStore?
    }
    private func make(ids: [String] = ["a", "b", "c"], fault: PendingFaultTestStore.Fault? = nil,
                      markReadOnly: Bool = false, mode: ReviewMode = .segment,
                      favoriteStoreFailure: Bool = false) async throws -> Context {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Intent.store")
        let store = try LocalStateStore(url: url)
        let failure = fault.map { PendingFaultTestStore(base: store, fault: $0) }
        let sessionStore: any LocalStateRepository = failure.map { $0 as any LocalStateRepository } ?? store
        let pendingStore: any LocalStateRepository = markReadOnly ? try LocalStateStore(url: url, allowsSave: false) : sessionStore
        let assets = ["a", "b", "c"].enumerated().map { index, id in
            PhotoAssetSnapshot(id: id, kind: .photo, creationDate: Date(timeIntervalSince1970: Double(index) * 86_400),
                               modificationDate: .distantPast, width: 100, height: 100, duration: 0,
                               isFavorite: false, isLivePhoto: false)
        }
        let writer = FavoriteTests.Writer(assets)
        let review = ReviewSession(store: sessionStore)
        review.updateLibrary(LibrarySnapshot(permission: .full, assets: assets, sharedLibraryMembershipVerified: true))
        try await review.start(ReviewSegment(assetIDs: ids, start: assets.first?.creationDate, end: assets.last?.creationDate), mode: mode)
        let pending = PendingCoordinator(store: pendingStore, reader: writer)
        let favoriteStore: any LocalStateRepository = favoriteStoreFailure ? FavoriteTests.CompletionFailStore(store) : store
        let favorites = FavoriteCoordinator(store: favoriteStore, writer: writer)
        let actions = ReviewActions(review: review, favorites: favorites, pending: pending, readSnapshot: {
            var fresh: [PhotoAssetSnapshot] = []
            for id in ["a", "b", "c"] { if let value = try? await writer.asset(id: id) { fresh.append(value) } }
            return LibrarySnapshot(permission: .full, assets: fresh, sharedLibraryMembershipVerified: true)
        })
        actions.appear()
        return Context(store: store, review: review, pending: pending, favorites: favorites, writer: writer, actions: actions, fault: failure)
    }
    private func intent(_ id: String = "a", _ kind: ReviewIntent.Kind = .pending) -> ReviewIntent {
        ReviewIntent(assetID: id, kind: kind)
    }

    func testSavedPendingAdvancesAndUndoRestoresOriginalCursorOnDisk() async throws {
        let c = try await make()
        var transitions = 0
        let advanced = await c.actions.perform(intent()) {
            transitions += 1
            XCTAssertEqual(c.review.currentID, "a")
            XCTAssertEqual(c.pending.items.map(\.assetID), ["a"])
            XCTAssertTrue(c.actions.isBusy)
        }
        XCTAssertTrue(advanced); XCTAssertEqual(transitions, 1)
        XCTAssertEqual(c.review.currentID, "b"); XCTAssertTrue(c.actions.showsPendingUndo)
        await c.actions.undo()
        XCTAssertEqual(c.review.currentID, "a"); XCTAssertFalse(c.actions.canUndo)
        XCTAssertTrue(try c.store.pending().isEmpty)
        XCTAssertEqual(try c.store.latestSession()?.cursor, 0)
    }
    func testFailedMarkNeverAnimatesOrAdvances() async throws {
        let c = try await make(markReadOnly: true)
        let advanced = await c.actions.perform(intent()) { XCTFail("An unsaved mark must never exit") }
        XCTAssertFalse(advanced); XCTAssertEqual(c.review.currentID, "a")
        XCTAssertTrue(try c.store.pending().isEmpty); XCTAssertFalse(c.actions.canUndo)
        XCTAssertEqual(c.actions.feedback, "待删标记未保存，请重试")
        XCTAssertFalse(c.actions.isBusy)
    }
    func testPositionFailurePreservesSavedMarkAndRetryDoesNotRepeatIt() async throws {
        let c = try await make(fault: .position)
        c.fault?.armOnce()
        let failed = await c.actions.perform(intent())
        XCTAssertFalse(failed); XCTAssertEqual(c.review.currentID, "a")
        let saved = try XCTUnwrap(c.store.pending().first)
        XCTAssertTrue(c.actions.canUndo)
        XCTAssertEqual(c.actions.feedback, "已加入待删，但位置未保存。可重试待删按钮或撤销")
        let retried = await c.actions.perform(intent())
        XCTAssertTrue(retried); XCTAssertEqual(c.review.currentID, "b")
        XCTAssertEqual(try c.store.pending(), [saved])
        await c.actions.undo(); XCTAssertEqual(c.review.currentID, "a")
    }
    func testUndoWriteFailureRemainsRetryable() async throws {
        let c = try await make(ids: ["a"], fault: .undo)
        await c.actions.perform(intent()); XCTAssertTrue(c.review.isComplete)
        c.fault?.armOnce(); await c.actions.undo()
        XCTAssertNotNil(c.actions.pendingFailure); XCTAssertTrue(c.actions.canUndo)
        XCTAssertEqual(try c.store.pending().count, 1)
        c.actions.dismissPendingFailure(); await c.actions.undo()
        XCTAssertEqual(c.review.currentID, "a"); XCTAssertNil(c.actions.pendingFailure)
        XCTAssertTrue(try c.store.pending().isEmpty)
    }
    func testUnmarkSuccessWithFailedRestoreOffersPositionOnlyRetry() async throws {
        let c = try await make(ids: ["a"], fault: .position)
        await c.actions.perform(intent()); XCTAssertTrue(c.review.isComplete)
        c.fault?.armOnce(); await c.actions.undo()
        XCTAssertTrue(try c.store.pending().isEmpty)
        XCTAssertTrue(c.actions.needsPositionRecovery); XCTAssertFalse(c.actions.canUndo)
        XCTAssertNotNil(c.actions.pendingFailure); XCTAssertTrue(c.review.isComplete)
        c.actions.dismissPendingFailure(); await c.actions.restorePosition()
        XCTAssertEqual(c.review.currentID, "a"); XCTAssertFalse(c.actions.needsPositionRecovery)
        XCTAssertEqual(try c.store.latestSession()?.completed, false)
    }
    func testNearbyThenUndoRestoresOriginalSession() async throws {
        let c = try await make(ids: ["a"], mode: .anniversary)
        let original = try XCTUnwrap(c.review.state)
        await c.actions.perform(intent()); XCTAssertTrue(c.review.isComplete)
        await c.actions.exploreNearby(); XCTAssertNotEqual(c.review.state?.id, original.id)
        await c.actions.undo()
        XCTAssertEqual(c.review.currentID, "a"); XCTAssertEqual(c.review.state?.id, original.id)
        XCTAssertEqual(c.review.state?.mode, .anniversary)
        XCTAssertEqual(try c.store.latestSession()?.id, original.id)
    }
    func testMostRecentFavoriteOwnsUndoAfterEarlierPending() async throws {
        let c = try await make()
        await c.actions.perform(intent()); XCTAssertEqual(c.review.currentID, "b")
        await c.actions.perform(intent("b", .favorite))
        XCTAssertEqual(c.review.currentID, "b"); XCTAssertTrue(c.actions.canUndo)
        XCTAssertFalse(c.actions.showsPendingUndo)
        await c.actions.navigate(.next); await c.actions.undo()
        let favorite = try await c.writer.asset(id: "b")
        XCTAssertFalse(favorite.isFavorite); XCTAssertEqual(c.review.currentID, "c")
        XCTAssertEqual(try c.store.pending().map(\.assetID), ["a"])
        XCTAssertFalse(c.actions.canUndo)
    }
    func testFavoriteConfirmationCapturesTargetAndPendingOwnsNextUndo() async throws {
        let c = try await make()
        await c.actions.perform(intent("a", .favorite))
        let unconfirmed = await c.actions.perform(intent()) { XCTFail("Must confirm first") }
        XCTAssertFalse(unconfirmed); XCTAssertEqual(c.actions.favoritePendingID, "a")
        // SwiftUI can dismiss the alert binding before its button Task runs.
        c.actions.dismissFavoriteConfirmation()
        let confirmed = await c.actions.confirmPending("a")
        XCTAssertTrue(confirmed); XCTAssertEqual(c.review.currentID, "b")
        await c.actions.undo()
        let asset = try await c.writer.asset(id: "a")
        XCTAssertTrue(asset.isFavorite); XCTAssertEqual(c.review.currentID, "a")
        XCTAssertTrue(try c.store.pending().isEmpty)
    }
    func testStaleConfirmationCannotMarkNewCurrentAsset() async throws {
        let c = try await make()
        await c.actions.perform(intent("a", .favorite)); await c.actions.perform(intent())
        await c.actions.navigate(.next)
        let changed = await c.actions.confirmPending("a")
        XCTAssertFalse(changed); XCTAssertEqual(c.review.currentID, "b")
        XCTAssertTrue(try c.store.pending().isEmpty)
    }
    func testExternalFavoriteChangePreventsUndoAndRefreshesFacts() async throws {
        let c = try await make()
        await c.actions.perform(intent("a", .favorite))
        await c.writer.replace(FavoriteTests.snapshot("a", favorite: true, version: .distantFuture))
        await c.actions.undo()
        let writes = await c.writer.calls
        XCTAssertEqual(writes, ["a"]); XCTAssertFalse(c.actions.canUndo)
        XCTAssertEqual(c.actions.feedback, "照片状态已变化，未覆盖新的收藏状态")
        XCTAssertEqual(c.review.snapshot.assets.first?.modificationDate, .distantFuture)
    }
    func testFavoriteJournalFailureDoesNotOfferFalseUndo() async throws {
        let c = try await make(favoriteStoreFailure: true)
        await c.actions.perform(intent("a", .favorite))
        XCTAssertEqual(c.actions.feedback, "已收藏，本地记录待核对")
        XCTAssertFalse(c.actions.canUndo)
        XCTAssertEqual(try c.store.operations().first?.phase, .submitted)
        let asset = try await c.writer.asset(id: "a"); XCTAssertTrue(asset.isFavorite)
    }
    func testTransitionRejectsDuplicateNavigationAndUndo() async throws {
        let c = try await make()
        let advanced = await c.actions.perform(intent()) {
            let duplicate = await c.actions.perform(self.intent()) { XCTFail("Only one transition") }
            XCTAssertFalse(duplicate)
            await c.actions.navigate(.next); await c.actions.undo()
            XCTAssertEqual(c.review.currentID, "a")
            XCTAssertEqual(c.pending.items.map(\.assetID), ["a"])
            await Task.yield()
        }
        XCTAssertTrue(advanced); XCTAssertEqual(c.review.currentID, "b")
        XCTAssertFalse(c.actions.isBusy)
    }
    func testRetiredPresentationCannotAdvanceAfterReappearing() async throws {
        let c = try await make()
        let advanced = await c.actions.perform(intent()) {
            c.actions.disappear(); await Task.yield(); c.actions.appear()
        }
        XCTAssertFalse(advanced); XCTAssertEqual(c.review.currentID, "a")
        XCTAssertEqual(try c.store.pending().map(\.assetID), ["a"])
        XCTAssertFalse(c.actions.isBusy)
        await c.actions.prepare()
        XCTAssertEqual(c.review.currentID, "b", "Existing durable-mark recovery still applies")
    }
    func testChangedSessionDuringTransitionIsNeverAdvanced() async throws {
        let c = try await make()
        let advanced = await c.actions.perform(intent()) {
            try? await c.review.start(ReviewSegment(assetIDs: ["b", "c"], start: nil, end: nil))
        }
        XCTAssertFalse(advanced); XCTAssertEqual(c.review.currentID, "b")
        XCTAssertEqual(c.review.state?.cursor, 0)
        await c.actions.undo(); XCTAssertEqual(c.review.currentID, "a")
    }
}
