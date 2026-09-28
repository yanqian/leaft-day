import Foundation

struct SessionState: Codable, Sendable, Equatable {
    var id: UUID
    var assetIDs: [String]
    var cursor: Int
    var updatedAt: Date
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
    func operations() async throws -> [OperationState]
}

enum LocalStateError: Error { case invalidSession, invalidAsset, invalidOperation, readOnly }
