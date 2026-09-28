import XCTest
import Photos
@testable import SwipeGo

@MainActor final class ReconciliationTests: XCTestCase {
    func storeURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: dir) }
        return dir.appendingPathComponent("Intent.store")
    }
    func testRestartWithMissingAssetPreservesIntentAndRequiresFreshReview() async throws {
        let url = try storeURL(); var before: LocalStateStore? = try LocalStateStore(url: url)
        let intent = PendingIntent(assetID: "missing", markedAt: .distantPast)
        try await before!.markPending(intent)
        let frozen = FrozenDeletion(id: UUID(), intents: [intent], targets: [FavoriteTests.snapshot("missing")], keepers: [])
        var operation = try await before!.prepareDeletion(frozen); operation.phase = .submitted
        try await before!.saveOperation(operation); before = nil // interrupted before local success receipt
        let reopened = try LocalStateStore(url: url)
        let model = ReconciliationCoordinator(store: reopened, reader: FavoriteTests.Writer([]), activity: OperationActivity())
        await model.refresh()
        XCTAssertEqual(model.records.count, 1); XCTAssertTrue(model.records[0].visible.isEmpty)
        XCTAssertEqual(model.records[0].operation.phase, .needsReview)
        let pending = try await reopened.pending(); XCTAssertEqual(pending, [intent])
        do { _ = try await reopened.prepareDeletion(FrozenDeletion(id: UUID(), intents: [intent], targets: frozen.targets, keepers: [])); XCTFail() } catch DeletionError.alreadySubmitted { }
        await model.acknowledge(model.records[0]); XCTAssertTrue(model.records.isEmpty)
        let recorded = try await reopened.operations(); XCTAssertEqual(recorded[0].phase, .needsReview); XCTAssertNotNil(recorded[0].reviewedAt)
        let stillPending = try await reopened.pending(); XCTAssertEqual(stillPending, [intent])
        let review = DeletionReviewModel(store: reopened, reader: FavoriteTests.Writer([]))
        await review.refresh(); await review.freeze(); XCTAssertNil(review.frozen, "Acknowledgement cannot make inaccessible assets deletable")
    }
    func testActiveOperationAndLaterSuccessCannotBeOverwritten() async throws {
        let store = try LocalStateStore(url: storeURL()); let activity = OperationActivity()
        let operation = OperationState(id: UUID(), kind: .favorite, targetIDs: ["a"], phase: .submitted, updatedAt: .distantPast)
        try await store.saveOperation(operation); activity.ids.insert(operation.id)
        let model = ReconciliationCoordinator(store: store, reader: FavoriteTests.Writer([FavoriteTests.snapshot("a", favorite: true)]), activity: activity)
        await model.refresh(); XCTAssertTrue(model.records.isEmpty)
        var completed = operation; completed.phase = .succeeded; try await store.saveOperation(completed)
        var stale = operation; stale.phase = .needsReview
        let changed = try await store.replaceOperation(ifMatching: operation, with: stale); XCTAssertFalse(changed)
        activity.ids.remove(operation.id); await model.refresh(); XCTAssertTrue(model.records.isEmpty)
        let actual = try await store.operations(); XCTAssertEqual(actual[0].phase, .succeeded)
    }
    func testFavoriteFactsAndCancelledReceiptsRemainDistinct() async throws {
        let store = try LocalStateStore(url: storeURL())
        let interrupted = OperationState(id: UUID(), kind: .favorite, targetIDs: ["a"], phase: .prepared, updatedAt: .distantPast)
        var cancelled = OperationState(id: UUID(), kind: .deletion, targetIDs: ["b"], phase: .failed, updatedAt: .distantPast); cancelled.deletionOutcome = .cancelled
        try await store.saveOperation(interrupted); try await store.saveOperation(cancelled)
        let reader = FavoriteTests.Writer([FavoriteTests.snapshot("a", favorite: true)])
        let model = ReconciliationCoordinator(store: store, reader: reader, activity: OperationActivity())
        await model.refresh(); XCTAssertEqual(model.records.count, 1); XCTAssertTrue(model.records[0].visible[0].isFavorite)
        XCTAssertEqual(model.records[0].operation.phase, .needsReview, "Current favorite is not evidence of our earlier success")
        await reader.replace(FavoriteTests.snapshot("a", favorite: false, version: .distantFuture))
        await model.refresh(); XCTAssertFalse(model.records[0].visible[0].isFavorite)
    }
    func testAcknowledgementSaveFailureDoesNotHideUnresolvedOperation() async throws {
        let url = try storeURL(); let writable = try LocalStateStore(url: url)
        let operation = OperationState(id: UUID(), kind: .deletion, targetIDs: ["a"], phase: .needsReview, updatedAt: .distantPast)
        try await writable.saveOperation(operation)
        let model = ReconciliationCoordinator(store: try LocalStateStore(url: url, allowsSave: false), reader: FavoriteTests.Writer([]), activity: OperationActivity())
        await model.refresh(); await model.acknowledge(model.records[0])
        XCTAssertNotNil(model.error); XCTAssertEqual(model.records.count, 1)
        let saved = try await writable.operations(); XCTAssertNil(saved[0].reviewedAt)
    }
    func testRealPhotoKitObserverRefreshesFavoriteAndSessionFacts() async throws {
        #if targetEnvironment(simulator)
        let model = LibraryAccessModel(); await model.refresh()
        var identifier: String?
        PHAsset.fetchAssets(with: .image, options: nil).enumerateObjects { asset, _, _ in
            if PHAssetResource.assetResources(for: asset).contains(where: { $0.originalFilename == "landscape.jpg" }) { identifier = asset.localIdentifier }
        }
        let id = try XCTUnwrap(identifier)
        let writer = NativeFavoriteWriter(); let original = try await writer.asset(id: id)
        do {
            let changed = try await writer.setFavorite(id: id, value: !original.isFavorite, expected: original)
            for _ in 0..<100 {
                if model.snapshot.assets.first(where: { $0.id == id })?.isFavorite == changed.isFavorite { break }
                try await Task.sleep(for: .milliseconds(30))
            }
            XCTAssertEqual(model.snapshot.assets.first(where: { $0.id == id })?.isFavorite, changed.isFavorite)
            let review = ReviewSession(store: try LocalStateStore(url: storeURL())); review.updateLibrary(model.snapshot)
            try await review.start(ReviewSegment(assetIDs: [id], start: original.creationDate, end: original.creationDate))
            guard case .available(let fact) = review.current else { return XCTFail() }; XCTAssertEqual(fact.isFavorite, changed.isFavorite)
            review.updateLibrary(LibrarySnapshot(permission: .limited, assets: [], sharedLibraryMembershipVerified: false))
            guard case .unavailable = review.current else { return XCTFail() }
            XCTAssertEqual(review.state?.assetIDs, [id], "Visibility loss must preserve session context")
            _ = try await writer.setFavorite(id: id, value: original.isFavorite, expected: changed)
        } catch {
            if let current = try? await writer.asset(id: id), current.isFavorite != original.isFavorite { _ = try? await writer.setFavorite(id: id, value: original.isFavorite, expected: current) }
            throw error
        }
        #else
        throw XCTSkip("Generated fixture observer mutation is simulator-only")
        #endif
    }
}
