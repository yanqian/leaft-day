import XCTest
@testable import SwipeGo

@MainActor final class DeletionReviewTests: XCTestCase {
    actor Assets: PhotoAssetReading {
        func accessScope() -> PhotoAccessScope { PhotoAccessScope(permission: .full) }
        var values: [String: PhotoAssetSnapshot]
        init(_ assets: [PhotoAssetSnapshot]) { values = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) }) }
        func asset(id: String) throws -> PhotoAssetSnapshot { guard let value = values[id] else { throw FavoriteError.unavailable }; return value }
        func remove(_ id: String) { values.removeValue(forKey: id) }
    }
    func store() throws -> LocalStateStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: dir) }
        return try LocalStateStore(url: dir.appendingPathComponent("Intent.store"))
    }
    func intent(_ id: String, keeping: [String] = []) -> PendingIntent {
        PendingIntent(assetID: id, groupID: keeping.isEmpty ? nil : "group", markedAt: .distantPast,
            comparison: keeping.isEmpty ? nil : ComparisonContext(assetIDs: [id] + keeping, keptIDs: keeping))
    }
    func testMissingKeeperAndPermissionLossPreserveIntent() async throws {
        let store = try store(); let record = intent("a", keeping: ["b"])
        try await store.markPending(record)
        let reader = Assets([FavoriteTests.snapshot("a")]); let model = DeletionReviewModel(store: store, reader: reader)
        await model.refresh(); XCTAssertEqual(model.readyCount, 0); XCTAssertEqual(model.needsReviewCount, 1)
        await model.freeze(); XCTAssertNil(model.frozen)
        await reader.remove("a"); await model.refresh(); XCTAssertNil(model.rows.first?.asset)
        let records = try await store.pending(); XCTAssertEqual(records, [record])
        await model.retract(record); XCTAssertTrue(model.rows.isEmpty)
    }
    func testFrozenTargetsStayFixedAndNewRecordsRequireReview() async throws {
        let store = try store(); let a = intent("a", keeping: ["b"])
        try await store.markPending(a)
        let assets = ["a", "b", "c"].map { FavoriteTests.snapshot($0) }
        let model = DeletionReviewModel(store: store, reader: Assets(assets))
        await model.refresh(); await model.freeze()
        let frozen = try XCTUnwrap(model.frozen)
        XCTAssertEqual(frozen.targets.map(\.id), ["a"]); XCTAssertEqual(frozen.keepers.map(\.id), ["b"])
        try await store.markPending(intent("c"))
        XCTAssertEqual(frozen.targets.map(\.id), ["a"])
        await model.freeze(); XCTAssertNil(model.frozen); XCTAssertNotNil(model.error)
        await model.freeze(); XCTAssertEqual(model.frozen?.targets.map(\.id), ["a", "c"])
        await model.refresh(); XCTAssertNil(model.frozen)
    }
    func testRetractionCannotRemoveReplacedDecision() async throws {
        let store = try store(); let old = intent("a")
        try await store.markPending(old)
        try await store.removePending(assetID: "a")
        var replacement = old; replacement.markedAt = .distantFuture
        try await store.markPending(replacement)
        let model = DeletionReviewModel(store: store, reader: Assets([FavoriteTests.snapshot("a")]))
        await model.refresh(); await model.retract(old)
        XCTAssertNotNil(model.error)
        let current = try await store.pending(); XCTAssertEqual(current, [replacement])
    }
    func testConflictingKeepDecisionIsExcludedFromReadyCount() async throws {
        let store = try store(); let records = [intent("a", keeping: ["b"]), intent("b")]
        for record in records { try await store.markPending(record) }
        let assets = ["a", "b"].map { FavoriteTests.snapshot($0) }
        XCTAssertEqual(DeletionReviewModel.readyCount(records, assets: assets), 1)
        let model = DeletionReviewModel(store: store, reader: Assets(assets))
        await model.refresh(); XCTAssertEqual(model.readyCount, 1); XCTAssertEqual(model.needsReviewCount, 1)
        await model.freeze(); XCTAssertNil(model.frozen)
    }
}
