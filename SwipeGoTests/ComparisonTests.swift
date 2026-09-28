import XCTest
@testable import SwipeGo

@MainActor final class ComparisonTests: XCTestCase {
    func url() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("Intent.store")
    }
    func testAtomicSelectionRetainsContextAndRetractsKeptPending() async throws {
        let path = try url(); let store = try LocalStateStore(url: path)
        let assets = ["a", "b", "c"].map { FavoriteTests.snapshot($0) }
        let reader = FavoriteTests.Writer(assets)
        let coordinator = PendingCoordinator(store: store, reader: reader)
        try await coordinator.mark("a")
        let count = try await coordinator.compare(assets, keeping: ["a", "c"])
        XCTAssertEqual(count, 1); XCTAssertNil(coordinator.undoRecord)
        let reopened = try await LocalStateStore(url: path).pending()
        XCTAssertEqual(reopened.map(\.assetID), ["b"])
        XCTAssertEqual(reopened.first?.comparison, ComparisonContext(assetIDs: ["a", "b", "c"], keptIDs: ["a", "c"]))
        _ = try await coordinator.compare(assets, keeping: Set(assets.map(\.id)))
        XCTAssertTrue(coordinator.items.isEmpty)
        let writes = await reader.calls; XCTAssertTrue(writes.isEmpty)
    }
    func testZeroKeepFavoriteAndChangedAssetCannotSave() async throws {
        let store = try LocalStateStore(url: url())
        let assets = [FavoriteTests.snapshot("a", favorite: true), FavoriteTests.snapshot("b")]
        let reader = FavoriteTests.Writer(assets)
        let coordinator = PendingCoordinator(store: store, reader: reader)
        do { try await coordinator.compare(assets, keeping: []); XCTFail() } catch PendingCoordinator.Failure.invalidSelection { }
        do { try await coordinator.compare(assets, keeping: ["b"]); XCTFail() } catch PendingCoordinator.Failure.confirmFavorite { }
        let stale = [FavoriteTests.snapshot("a"), assets[1]]
        do { try await coordinator.compare(stale, keeping: ["a"]); XCTFail() } catch PendingCoordinator.Failure.changed { }
        let records = try await store.pending(); XCTAssertTrue(records.isEmpty)
    }
    func testReadOnlyBatchFailurePreservesOriginalIntent() async throws {
        let path = try url(); let store = try LocalStateStore(url: path)
        let original = PendingIntent(assetID: "a", groupID: nil, markedAt: .distantPast)
        try await store.markPending(original)
        let assets = ["a", "b", "c"].map { FavoriteTests.snapshot($0) }
        let coordinator = PendingCoordinator(store: try LocalStateStore(url: path, allowsSave: false), reader: FavoriteTests.Writer(assets))
        do { try await coordinator.compare(assets, keeping: ["a"]); XCTFail() } catch { }
        let actual = try await store.pending(); XCTAssertEqual(actual, [original])
        XCTAssertTrue(coordinator.items.isEmpty)
    }
    func testOldPendingPayloadDecodesWithoutComparison() throws {
        let data = Data(#"{"assetID":"old","markedAt":0}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(PendingIntent.self, from: data).comparison)
    }
}
