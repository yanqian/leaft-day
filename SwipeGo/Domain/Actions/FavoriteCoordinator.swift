import Foundation
import Observation

@MainActor @Observable final class FavoriteCoordinator {
    struct Undo: Equatable { let assetID: String; let before: Bool; let after: PhotoAssetSnapshot }
    struct Result { let asset: PhotoAssetSnapshot; let changed: Bool; let journalSaved: Bool }
    private(set) var undoRecord: Undo?
    private(set) var isBusy = false
    @ObservationIgnored private let store: any LocalStateRepository
    @ObservationIgnored private let writer: any FavoriteWriting
    init(store: any LocalStateRepository, writer: any FavoriteWriting = NativeFavoriteWriter()) {
        self.store = store; self.writer = writer
    }
    func favorite(_ id: String) async throws -> Result {
        guard !isBusy else { throw FavoriteError.busy }; isBusy = true; defer { isBusy = false }
        let before = try await writer.asset(id: id)
        guard !before.isFavorite else { return Result(asset: before, changed: false, journalSaved: true) }
        let result = try await change(before, to: true)
        undoRecord = result.journalSaved ? Undo(assetID: id, before: before.isFavorite, after: result.asset) : nil
        return result
    }
    func undo() async throws -> Result {
        guard !isBusy else { throw FavoriteError.busy }
        guard let record = undoRecord else { throw FavoriteError.noUndo }
        isBusy = true; defer { isBusy = false }
        let current = try await writer.asset(id: record.assetID)
        guard current == record.after else { undoRecord = nil; throw FavoriteError.changed }
        let result = try await change(current, to: record.before)
        undoRecord = nil
        return result
    }
    private func change(_ before: PhotoAssetSnapshot, to value: Bool) async throws -> Result {
        var operation = OperationState(id: UUID(), kind: .favorite, targetIDs: [before.id], phase: .prepared, updatedAt: .now)
        try await store.saveOperation(operation)
        operation.phase = .submitted; operation.updatedAt = .now
        try await store.saveOperation(operation)
        let after: PhotoAssetSnapshot
        do { after = try await writer.setFavorite(id: before.id, value: value, expected: before) }
        catch {
            // A thrown completion can include post-write visibility loss: do not assert rollback.
            if case FavoriteError.cancelled = error { operation.phase = .failed }
            else { operation.phase = .needsReview }
            operation.updatedAt = .now
            try? await store.saveOperation(operation)
            throw error
        }
        operation.phase = .succeeded; operation.updatedAt = .now
        do {
            try await store.saveOperation(operation)
            return Result(asset: after, changed: true, journalSaved: true)
        } catch {
            // The system receipt is real even if this local save fails; leave durable submitted record.
            return Result(asset: after, changed: true, journalSaved: false)
        }
    }
}
