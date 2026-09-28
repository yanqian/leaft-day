import XCTest
@testable import SwipeGo

@MainActor final class DeletionTests: XCTestCase {
    actor Writer: DeletionWriting {
        var values: [String: PhotoAssetSnapshot]
        var scope = PhotoAccessScope(permission: .full)
        var calls = 0
        var failure: DeletionError?
        var delay = false
        init(_ assets: [PhotoAssetSnapshot]) { values = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) }) }
        func accessScope() -> PhotoAccessScope { scope }
        func asset(id: String) throws -> PhotoAssetSnapshot { guard let value = values[id] else { throw DeletionError.changed }; return value }
        func delete(_ frozen: FrozenDeletion) async throws {
            calls += 1
            if delay { try await Task.sleep(for: .milliseconds(100)) }
            if let failure { throw failure }
            for asset in frozen.targets { values.removeValue(forKey: asset.id) }
        }
        func configure(_ error: DeletionError? = nil, delay: Bool = false) { failure = error; self.delay = delay }
        func restrict() { scope = PhotoAccessScope(permission: .limited, limitedIDs: ["a", "b"]) }
        func replace(_ asset: PhotoAssetSnapshot) { values[asset.id] = asset }
    }
    func storeURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: dir) }
        return dir.appendingPathComponent("Intent.store")
    }
    func setup() async throws -> (LocalStateStore, FrozenDeletion, Writer) {
        let store = try LocalStateStore(url: storeURL())
        let a = FavoriteTests.snapshot("a"), b = FavoriteTests.snapshot("b")
        let intent = PendingIntent(assetID: "a", groupID: "g", markedAt: .distantPast, comparison: ComparisonContext(assetIDs: ["a", "b"], keptIDs: ["b"]))
        try await store.markPending(intent)
        return (store, FrozenDeletion(id: UUID(), intents: [intent], targets: [a], keepers: [b]), Writer([a, b]))
    }
    func testSuccessIsAtomicAndBatchCannotBeResubmitted() async throws {
        let (store, frozen, writer) = try await setup(); let coordinator = DeletionCoordinator(store: store, writer: writer)
        let extra = PendingIntent(assetID: "later", markedAt: .now); try await store.markPending(extra)
        let result = try await coordinator.execute(frozen)
        guard case .succeeded = result else { return XCTFail() }
        let pending = try await store.pending(); XCTAssertEqual(pending, [extra])
        let operations = try await store.operations(); XCTAssertEqual(operations.first?.phase, .succeeded); XCTAssertEqual(operations.first?.deletion, frozen)
        do { _ = try await coordinator.execute(frozen); XCTFail() } catch { }
        let calls = await writer.calls; XCTAssertEqual(calls, 1)
        let keeper = try await writer.asset(id: "b"); XCTAssertEqual(keeper, frozen.keepers[0])
    }
    func testCancelUnknownAndCompletionSaveFailurePreserveIntent() async throws {
        for failure in [DeletionError.cancelled, .unknown] {
            let (store, frozen, writer) = try await setup(); await writer.configure(failure)
            _ = try await DeletionCoordinator(store: store, writer: writer).execute(frozen)
            let pending = try await store.pending(); XCTAssertEqual(pending, frozen.intents)
            let operation = try await store.operations().first
            if case .cancelled = failure { XCTAssertEqual(operation?.deletionOutcome, .cancelled); XCTAssertEqual(operation?.phase, .failed) }
            else { XCTAssertEqual(operation?.phase, .needsReview) }
        }
        let (store, frozen, writer) = try await setup()
        let result = try await DeletionCoordinator(store: FavoriteTests.CompletionFailStore(store), writer: writer).execute(frozen)
        guard case .succeededJournalPending = result else { return XCTFail() }
        let pending = try await store.pending(); XCTAssertEqual(pending, frozen.intents)
        let journal = try await store.operations(); XCTAssertEqual(journal.first?.phase, .submitted)
    }
    func testChangedPermissionKeeperIntentAndReadOnlyStopBeforeNativeWrite() async throws {
        for change in 0..<4 {
            let (store, frozen, writer) = try await setup()
            switch change {
            case 0: await writer.restrict()
            case 1: await writer.replace(FavoriteTests.snapshot("b", version: .distantFuture))
            case 2: try await store.removePending(assetID: "a")
            default: _ = try await store.prepareDeletion(frozen)
            }
            do { _ = try await DeletionCoordinator(store: store, writer: writer).execute(frozen); XCTFail() } catch { }
            let calls = await writer.calls; XCTAssertEqual(calls, 0)
        }
        let (_, frozen, writer) = try await setup()
        let url = try storeURL(); let writable = try LocalStateStore(url: url)
        for intent in frozen.intents { try await writable.markPending(intent) }
        let readOnly = try LocalStateStore(url: url, allowsSave: false)
        do { _ = try await DeletionCoordinator(store: readOnly, writer: writer).execute(frozen); XCTFail() } catch { }
        let calls = await writer.calls; XCTAssertEqual(calls, 0)
    }
    func testConcurrentClickCannotDuplicateNativeSubmission() async throws {
        let (store, frozen, writer) = try await setup(); await writer.configure(delay: true)
        let coordinator = DeletionCoordinator(store: store, writer: writer)
        let first = Task { try await coordinator.execute(frozen) }
        while !coordinator.isBusy { await Task.yield() }
        do { _ = try await coordinator.execute(frozen); XCTFail() } catch DeletionError.busy { }
        _ = try await first.value
        let calls = await writer.calls; XCTAssertEqual(calls, 1)
    }
    func testOldOperationJSONStillDecodes() throws {
        let original = OperationState(id: UUID(), kind: .favorite, targetIDs: ["a"], phase: .submitted, updatedAt: .distantPast)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OperationState.self, from: data)
        XCTAssertNil(decoded.deletion); XCTAssertNil(decoded.deletionOutcome)
    }
}
