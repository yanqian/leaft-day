import XCTest
@testable import SwipeGo

@MainActor
final class LocalStateStoreTests: XCTestCase {
    private func storeURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("Intent.store")
    }

    func testRealDiskReopenPreservesAllIntentAndDeduplicates() async throws {
        let url = try storeURL()
        let id = UUID()
        let now = Date(timeIntervalSince1970: 100)
        let session = SessionState(id: id, assetIDs: ["a", "b"], cursor: 1, updatedAt: now)
        let mark = PendingIntent(assetID: "b", groupID: "group", markedAt: now)
        let operation = OperationState(id: UUID(), kind: .deletion, targetIDs: ["b"], phase: .prepared, updatedAt: now)
        var writer: LocalStateStore? = try LocalStateStore(url: url)
        try await writer!.saveSession(session)
        try await writer!.markPending(mark)
        try await writer!.markPending(PendingIntent(assetID: "b", groupID: nil, markedAt: Date()))
        try await writer!.saveOperation(operation)
        writer = nil
        let reopened = try LocalStateStore(url: url)
        let actualSession = try await reopened.session(id: id)
        let actualPending = try await reopened.pending()
        let actualOperations = try await reopened.operations()
        XCTAssertEqual(actualSession, session)
        XCTAssertEqual(actualPending, [mark])
        XCTAssertEqual(actualOperations, [operation])
        try await reopened.removePending(assetID: "b")
        let again = try LocalStateStore(url: url)
        let empty = try await again.pending()
        XCTAssertTrue(empty.isEmpty)
    }

    func testConcurrentMarksOnSingleRepositoryRemainUnique() async throws {
        let store = try LocalStateStore(url: storeURL())
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { try await store.markPending(PendingIntent(assetID: "a", groupID: nil, markedAt: .distantPast)) }
            }
            try await group.waitForAll()
        }
        let pending = try await store.pending()
        XCTAssertEqual(pending.count, 1)
    }

    func testReadOnlyWriteFailsAndDoesNotMutateRealStore() async throws {
        let url = try storeURL()
        var writer: LocalStateStore? = try LocalStateStore(url: url)
        try await writer!.markPending(PendingIntent(assetID: "keep", groupID: nil, markedAt: .distantPast))
        writer = nil
        let readOnly = try LocalStateStore(url: url, allowsSave: false)
        do {
            try await readOnly.markPending(PendingIntent(assetID: "reject", groupID: nil, markedAt: .distantPast))
            XCTFail("Write to read-only repository must fail")
        } catch {
            // This is a real SwiftData save error, not an injected repository guard.
            XCTAssertFalse(error is LocalStateError)
        }
        let rolledBack = try await readOnly.pending()
        XCTAssertEqual(rolledBack.map(\.assetID), ["keep"])
        let reader = try LocalStateStore(url: url)
        let actual = try await reader.pending()
        XCTAssertEqual(actual.map(\.assetID), ["keep"])
    }

    func testInvalidSessionDoesNotReplaceSavedCursor() async throws {
        let store = try LocalStateStore(url: storeURL())
        let id = UUID()
        let valid = SessionState(id: id, assetIDs: ["a"], cursor: 0, updatedAt: .distantPast)
        try await store.saveSession(valid)
        do {
            try await store.saveSession(SessionState(id: id, assetIDs: ["a"], cursor: 4, updatedAt: .now))
            XCTFail("Invalid cursor accepted")
        } catch LocalStateError.invalidSession { }
        let actual = try await store.session(id: id)
        XCTAssertEqual(actual, valid)
    }
}
