import Foundation
import Observation

struct PhotoAccessScope: Codable, Equatable, Sendable {
    let permission: LibraryPermission
    var limitedIDs: [String] = []
}

enum DeletionError: Error { case changed, busy, alreadySubmitted, cancelled, unknown }
protocol DeletionWriting: PhotoAssetReading {
    func delete(_ frozen: FrozenDeletion) async throws
}

@MainActor @Observable final class DeletionCoordinator {
    enum Result { case succeeded, cancelled, failed, needsReview, succeededJournalPending }
    private(set) var isBusy = false
    private(set) var lastAttemptID: UUID?
    @ObservationIgnored private let store: any LocalStateRepository
    @ObservationIgnored private let writer: any DeletionWriting
    init(store: any LocalStateRepository, writer: any DeletionWriting = NativeDeletionWriter()) { self.store = store; self.writer = writer }
    func execute(_ frozen: FrozenDeletion) async throws -> Result {
        guard !isBusy else { throw DeletionError.busy }
        isBusy = true; lastAttemptID = frozen.id; defer { isBusy = false }
        guard frozen.scope.permission.canRead, await writer.accessScope() == frozen.scope else { throw DeletionError.changed }
        for expected in frozen.targets + frozen.keepers {
            guard try await writer.asset(id: expected.id) == expected else { throw DeletionError.changed }
        }
        guard await writer.accessScope() == frozen.scope else { throw DeletionError.changed }
        // Atomically reserve the immutable batch against current intents and unresolved operations.
        var operation = try await store.prepareDeletion(frozen)
        operation.phase = .submitted; operation.updatedAt = .now
        try await store.saveOperation(operation) // failure stops before any native call
        do { try await writer.delete(frozen) }
        catch {
            let result: Result
            switch error {
            case DeletionError.cancelled: operation.phase = .failed; operation.deletionOutcome = .cancelled; result = .cancelled
            case DeletionError.changed: operation.phase = .failed; operation.deletionOutcome = .notSubmitted; result = .failed
            default: operation.phase = .needsReview; operation.deletionOutcome = .unknown; result = .needsReview
            }
            operation.updatedAt = .now
            do { try await store.saveOperation(operation) } catch { return .needsReview }
            return result
        }
        // Only an actual successful batch receipt permits clearing the matching local intents.
        operation.phase = .succeeded; operation.deletionOutcome = .success; operation.updatedAt = .now
        do { try await store.completeDeletion(operation); return .succeeded }
        catch { return .succeededJournalPending }
    }
}
