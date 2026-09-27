import XCTest
@testable import SwipeGo

@MainActor final class PendingTests: XCTestCase {
    func storeURL() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("Intent.store")
    }
    func testMarkRepeatReopenAndUndoOriginalAsset() async throws {
        let url = try storeURL(); let store = try LocalStateStore(url: url)
        let reader = FavoriteTests.Writer([FavoriteTests.snapshot("a"), FavoriteTests.snapshot("b")])
        let coordinator = PendingCoordinator(store: store, reader: reader)
        let first = try await coordinator.mark("a"); XCTAssertTrue(first)
        let again = try await coordinator.mark("a"); XCTAssertFalse(again)
        let reopened = PendingCoordinator(store: try LocalStateStore(url: url), reader: reader)
        try await reopened.reload(); XCTAssertEqual(reopened.items, coordinator.items); XCTAssertEqual(reopened.items.count, 1)
        _ = try await reader.asset(id: "b")
        try await coordinator.undo(); XCTAssertTrue(coordinator.items.isEmpty)
        let disk = try await store.pending(); XCTAssertTrue(disk.isEmpty)
        let writes = await reader.calls; XCTAssertTrue(writes.isEmpty, "Pending must never write PhotoKit")
    }
    func testFavoriteRequiresExplicitConfirmationAndKeepsFavorite() async throws {
        let store = try LocalStateStore(url: storeURL())
        let reader = FavoriteTests.Writer([FavoriteTests.snapshot("a", favorite: true)])
        let coordinator = PendingCoordinator(store: store, reader: reader)
        do { try await coordinator.mark("a"); XCTFail() } catch PendingCoordinator.Failure.confirmFavorite { }
        let empty = try await store.pending(); XCTAssertTrue(empty.isEmpty)
        try await coordinator.mark("a", confirmedFavorite: true)
        let favorite = try await reader.asset(id: "a"); XCTAssertTrue(favorite.isFavorite)
        let writes = await reader.calls; XCTAssertTrue(writes.isEmpty)
    }
    func testRealReadOnlyFailureNeverPublishesSuccess() async throws {
        let url = try storeURL(); let writable = try LocalStateStore(url: url)
        let reader = FavoriteTests.Writer([FavoriteTests.snapshot("a")])
        let coordinator = PendingCoordinator(store: try LocalStateStore(url: url, allowsSave: false), reader: reader)
        do { try await coordinator.mark("a"); XCTFail() } catch { }
        XCTAssertNil(coordinator.undoRecord); XCTAssertTrue(coordinator.items.isEmpty)
        let saved = try await writable.pending(); XCTAssertTrue(saved.isEmpty)
    }
    func testUndoRejectsReplacedRecord() async throws {
        let store = try LocalStateStore(url: storeURL())
        let coordinator = PendingCoordinator(store: store, reader: FavoriteTests.Writer([FavoriteTests.snapshot("a")]))
        try await coordinator.mark("a")
        try await store.removePending(assetID: "a")
        let replacement = PendingIntent(assetID: "a", groupID: "new-decision", markedAt: .distantFuture)
        try await store.markPending(replacement)
        do { try await coordinator.undo(); XCTFail() } catch PendingCoordinator.Failure.changed { }
        let actual = try await store.pending(); XCTAssertEqual(actual, [replacement])
    }
}
