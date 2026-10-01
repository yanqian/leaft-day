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


protocol LocalStateRepository: Sendable {
    func saveSession(_ value: SessionState) async throws
    func latestSession() async throws -> SessionState?
    func pending() async throws -> [PendingIntent]
}
@MainActor final class ProbeStore: LocalStateRepository {
    var value: SessionState?
    var items: [PendingIntent] = []
    func saveSession(_ value: SessionState) { self.value = value }
    func latestSession() -> SessionState? { value }
    func pending() -> [PendingIntent] { items }
}
@main struct Probe {
    @MainActor static func main() async throws {
        let store = ProbeStore()
        let review = ReviewSession(store: store)
        let assets = ["a", "b"].enumerated().map { index, id in
            PhotoAssetSnapshot(id: id, kind: .photo, creationDate: Date(timeIntervalSince1970: Double(index) * 86400), modificationDate: nil, width: 10, height: 10, duration: 0, isFavorite: false, isLivePhoto: false)
        }
        review.updateLibrary(LibrarySnapshot(permission: .full, assets: assets, sharedLibraryMembershipVerified: false))
        try await review.start(ReviewSegment(assetIDs: ["a"], start: assets[0].creationDate, end: assets[0].creationDate), mode: .anniversary)
        store.items = [PendingIntent(assetID: "a", groupID: nil, markedAt: .now)]
        review.updatePending(store.items)
        try await review.advanceAfterPending(assetID: "a", sessionID: review.state!.id)
        print("completed=\(review.isComplete), nearby=\(review.nearbySegment!.assetIDs)")
        try await review.exploreNearby()
        // Successful PendingCoordinator.undo removes the original mark and publishes items.
        store.items = []; review.updatePending(store.items)
        try await review.returnToUnmarked("a")
        print("undo original=a, current=\(review.currentID ?? "nil"), ids=\(review.state!.assetIDs), pending=\(store.items.count)")
        print(review.currentID == "a" ? "ORIGINAL_RESTORED" : "BUG: original photo was not restored; no error was thrown")
    }
}
