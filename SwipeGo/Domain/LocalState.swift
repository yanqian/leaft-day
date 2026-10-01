import Foundation

enum ReviewMode: String, Codable, Sendable { case segment, continuous, anniversary }

struct SessionState: Codable, Sendable, Equatable {
    var id: UUID
    var assetIDs: [String]
    var cursor: Int
    var updatedAt: Date
    var mode: ReviewMode? = nil
    var completed: Bool? = nil
}

struct PendingIntent: Codable, Sendable, Equatable {
    var assetID: String
    var groupID: String?
    var markedAt: Date
    var comparison: ComparisonContext? = nil
}

struct ComparisonContext: Codable, Sendable, Equatable {
    let assetIDs: [String]
    let keptIDs: [String]
}

struct OperationState: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable { case favorite, deletion }
    enum Phase: String, Codable, Sendable { case prepared, submitted, succeeded, failed, needsReview }
    enum DeletionOutcome: String, Codable, Sendable { case success, cancelled, notSubmitted, unknown }
    var deletion: FrozenDeletion? = nil
    var deletionOutcome: DeletionOutcome? = nil
    var reviewedAt: Date? = nil
    var requiresReview: Bool { reviewedAt == nil && [.prepared, .submitted, .needsReview].contains(phase) }
    var id: UUID
    var kind: Kind
    var targetIDs: [String]
    var phase: Phase
    var updatedAt: Date
}

protocol LocalStateRepository: Sendable {
    func saveSession(_ value: SessionState) async throws
    func latestSession() async throws -> SessionState?
    func session(id: UUID) async throws -> SessionState?
    func markPending(_ value: PendingIntent) async throws
    func saveComparison(_ values: [PendingIntent], keeping: [String]) async throws
    func pending() async throws -> [PendingIntent]
    func removePending(assetID: String) async throws
    func removePending(ifMatching expected: PendingIntent) async throws
    func saveOperation(_ value: OperationState) async throws
    func prepareDeletion(_ frozen: FrozenDeletion) async throws -> OperationState
    func completeDeletion(_ operation: OperationState) async throws
    func replaceOperation(ifMatching expected: OperationState, with next: OperationState) async throws -> Bool
    func operations() async throws -> [OperationState]
}

enum LocalStateError: Error { case invalidSession, invalidAsset, invalidOperation, readOnly }
