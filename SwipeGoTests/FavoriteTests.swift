import XCTest
import Photos
@testable import SwipeGo

@MainActor final class FavoriteTests: XCTestCase {
    static func snapshot(_ id: String, favorite: Bool = false, version: Date = .distantPast) -> PhotoAssetSnapshot {
        PhotoAssetSnapshot(id: id, kind: .photo, creationDate: .distantPast, modificationDate: version,
                           width: 100, height: 100, duration: 0, isFavorite: favorite, isLivePhoto: false)
    }
    actor Writer: FavoriteWriting {
        func accessScope() -> PhotoAccessScope { PhotoAccessScope(permission: .full) }
        var assets: [String: PhotoAssetSnapshot]
        var calls: [String] = []
        var fail = false
        init(_ assets: [PhotoAssetSnapshot]) { self.assets = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) }) }
        func asset(id: String) throws -> PhotoAssetSnapshot { guard let asset = assets[id] else { throw FavoriteError.unavailable }; return asset }
        func setFavorite(id: String, value: Bool, expected: PhotoAssetSnapshot) throws -> PhotoAssetSnapshot {
            guard assets[id] == expected else { throw FavoriteError.changed }
            calls.append(id)
            if fail { throw FavoriteError.cancelled }
            let next = PhotoAssetSnapshot(id: id, kind: .photo, creationDate: .distantPast, modificationDate: Date(),
                width: 100, height: 100, duration: 0, isFavorite: value, isLivePhoto: false)
            assets[id] = next; return next
        }
        func replace(_ asset: PhotoAssetSnapshot) { assets[asset.id] = asset }
        func setFailure() { fail = true }
    }
    actor CompletionFailStore: LocalStateRepository {
        func prepareDeletion(_ frozen: FrozenDeletion) async throws -> OperationState { try await base.prepareDeletion(frozen) }
        func completeDeletion(_ operation: OperationState) async throws { throw CocoaError(.fileWriteNoPermission) }
        func removePending(ifMatching expected: PendingIntent) async throws { throw LocalStateError.readOnly }
        func saveComparison(_ values: [PendingIntent], keeping: [String]) async throws { throw LocalStateError.readOnly }
        let base: LocalStateStore
        init(_ base: LocalStateStore) { self.base = base }
        func saveSession(_ value: SessionState) async throws { try await base.saveSession(value) }
        func session(id: UUID) async throws -> SessionState? { try await base.session(id: id) }
        func latestSession() async throws -> SessionState? { try await base.latestSession() }
        func markPending(_ value: PendingIntent) async throws { try await base.markPending(value) }
        func pending() async throws -> [PendingIntent] { try await base.pending() }
        func removePending(assetID: String) async throws { try await base.removePending(assetID: assetID) }
        func operations() async throws -> [OperationState] { try await base.operations() }
        func saveOperation(_ value: OperationState) async throws {
            if value.phase == .succeeded { throw CocoaError(.fileWriteNoPermission) }
            try await base.saveOperation(value)
        }
    }
    func testPostSystemJournalFailurePreservesSubmittedEvidence() async throws {
        let base = try LocalStateStore(url: storeURL()); let writer = Writer([Self.snapshot("a")])
        let coordinator = FavoriteCoordinator(store: CompletionFailStore(base), writer: writer)
        let result = try await coordinator.favorite("a")
        XCTAssertTrue(result.asset.isFavorite); XCTAssertFalse(result.journalSaved); XCTAssertNil(coordinator.undoRecord)
        let records = try await base.operations(); XCTAssertEqual(records.first?.phase, .submitted)
    }
    func storeURL() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("Intent.store")
    }
    func testIdempotentFavoriteAndUndoOriginalAsset() async throws {
        let store = try LocalStateStore(url: storeURL()); let writer = Writer([Self.snapshot("a"), Self.snapshot("b")])
        let coordinator = FavoriteCoordinator(store: store, writer: writer)
        let first = try await coordinator.favorite("a"); XCTAssertTrue(first.changed)
        let again = try await coordinator.favorite("a"); XCTAssertFalse(again.changed)
        _ = try await writer.asset(id: "b")
        let undo = try await coordinator.undo(); XCTAssertEqual(undo.asset.id, "a"); XCTAssertFalse(undo.asset.isFavorite)
        let calls = await writer.calls; XCTAssertEqual(calls, ["a", "a"])
        let records = try await store.operations(); XCTAssertEqual(records.count, 2); XCTAssertTrue(records.allSatisfy { $0.phase == .succeeded })
        XCTAssertNil(coordinator.undoRecord)
    }
    func testExternalStateOrVersionChangePreventsUndo() async throws {
        for externalFavorite in [false, true] {
            let writer = Writer([Self.snapshot("a")]); let coordinator = FavoriteCoordinator(store: try LocalStateStore(url: storeURL()), writer: writer)
            _ = try await coordinator.favorite("a")
            await writer.replace(Self.snapshot("a", favorite: externalFavorite, version: .distantFuture))
            do { _ = try await coordinator.undo(); XCTFail("Must not overwrite changed asset") } catch FavoriteError.changed { }
            let calls = await writer.calls; XCTAssertEqual(calls.count, 1); XCTAssertNil(coordinator.undoRecord)
        }
    }
    func testRealReadOnlySaveFailureNeverCallsWriter() async throws {
        let url = try storeURL(); _ = try LocalStateStore(url: url)
        let writer = Writer([Self.snapshot("a")])
        let coordinator = FavoriteCoordinator(store: try LocalStateStore(url: url, allowsSave: false), writer: writer)
        do { _ = try await coordinator.favorite("a"); XCTFail() } catch { }
        let calls = await writer.calls; XCTAssertTrue(calls.isEmpty); XCTAssertNil(coordinator.undoRecord)
        XCTAssertFalse(coordinator.isBusy)
    }
    func testSystemCancellationRecordsFailureWithoutUndo() async throws {
        let store = try LocalStateStore(url: storeURL()); let writer = Writer([Self.snapshot("a")]); await writer.setFailure()
        let coordinator = FavoriteCoordinator(store: store, writer: writer)
        do { _ = try await coordinator.favorite("a"); XCTFail() } catch FavoriteError.cancelled { }
        let actual = try await writer.asset(id: "a"); XCTAssertFalse(actual.isFavorite)
        let records = try await store.operations(); XCTAssertEqual(records.first?.phase, .failed)
        XCTAssertNil(coordinator.undoRecord)
    }
    func testRealPhotoKitFavoriteAndUndoOnGeneratedFixture() async throws {
        #if targetEnvironment(simulator)
        guard PhotoLibraryGateway.permission(PHPhotoLibrary.authorizationStatus(for: .readWrite)).canRead else { throw XCTSkip("Requires fixture simulator authorization") }
        var fixtureID: String?
        PHAsset.fetchAssets(with: .image, options: nil).enumerateObjects { asset, _, _ in
            if PHAssetResource.assetResources(for: asset).contains(where: { $0.originalFilename == "landscape.jpg" }) { fixtureID = asset.localIdentifier }
        }
        let id = try XCTUnwrap(fixtureID, "Install generated landscape.jpg fixture; never mutate personal media")
        let writer = NativeFavoriteWriter(); let original = try await writer.asset(id: id)
        do {
            if original.isFavorite { _ = try await writer.setFavorite(id: id, value: false, expected: original) }
            let coordinator = FavoriteCoordinator(store: try LocalStateStore(url: storeURL()), writer: writer)
            _ = try await coordinator.favorite(id)
            let actual = try await writer.asset(id: id); XCTAssertTrue(actual.isFavorite)
            let again = try await coordinator.favorite(id); XCTAssertFalse(again.changed)
            _ = try await coordinator.undo()
            let restored = try await writer.asset(id: id); XCTAssertFalse(restored.isFavorite)
            _ = try await coordinator.favorite(id)
            let beforeExternal = try await writer.asset(id: id)
            _ = try await writer.setFavorite(id: id, value: false, expected: beforeExternal)
            do { _ = try await coordinator.undo(); XCTFail("External native write must invalidate undo") } catch FavoriteError.changed { }
            let afterExternal = try await writer.asset(id: id); XCTAssertFalse(afterExternal.isFavorite)
            if original.isFavorite { _ = try await writer.setFavorite(id: id, value: true, expected: afterExternal) }
        } catch {
            if let current = try? await writer.asset(id: id), current.isFavorite != original.isFavorite {
                _ = try? await writer.setFavorite(id: id, value: original.isFavorite, expected: current)
            }
            throw error
        }
        #else
        throw XCTSkip("This automatic mutation test is simulator-only")
        #endif
    }
}
