import Foundation
import Observation

enum ReviewSessionError: Error { case busy, empty, unavailable, invalidSession }

@MainActor @Observable final class ReviewSession {
    enum Current: Equatable {
        case noSession
        case available(PhotoAssetSnapshot)
        case unavailable(String)
    }
    private(set) var state: SessionState?
    private(set) var isSaving = false
    private(set) var snapshot = LibrarySnapshot(permission: .notDetermined, assets: [], sharedLibraryMembershipVerified: false)
    @ObservationIgnored private let store: any LocalStateRepository
    init(store: any LocalStateRepository) { self.store = store }
    var current: Current {
        guard let state else { return .noSession }
        guard snapshot.permission.canRead else { return .unavailable(snapshot.permission.guidance) }
        guard state.assetIDs.indices.contains(state.cursor) else { return .unavailable("回顾位置需要重新核对。") }
        guard let asset = snapshot.assets.first(where: { $0.id == state.assetIDs[state.cursor] }) else {
            return .unavailable("此项目当前不可访问，可能是授权范围或图库发生变化。可切换前后项或管理照片权限。")
        }
        return .available(asset)
    }
    var currentID: String? {
        guard let state, state.assetIDs.indices.contains(state.cursor) else { return nil }
        return state.assetIDs[state.cursor]
    }
    var canGoBack: Bool { (state?.cursor ?? 0) > 0 }
    var canGoForward: Bool { guard let state else { return false }; return state.cursor + 1 < state.assetIDs.count }
    func updateLibrary(_ snapshot: LibrarySnapshot) { self.snapshot = snapshot }
    func restore() async throws {
        guard !isSaving else { throw ReviewSessionError.busy }; isSaving = true; defer { isSaving = false }
        let saved = try await store.latestSession()
        if let saved { try validate(saved) }
        state = saved
    }
    func start(_ segment: ReviewSegment, now: Date = .now) async throws {
        guard !isSaving else { throw ReviewSessionError.busy }
        guard !segment.assetIDs.isEmpty else { throw ReviewSessionError.empty }
        guard snapshot.permission.canRead, Set(segment.assetIDs).isSubset(of: Set(snapshot.assets.map(\.id))) else { throw ReviewSessionError.unavailable }
        let next = SessionState(id: UUID(), assetIDs: segment.assetIDs, cursor: 0, updatedAt: now)
        try validate(next)
        isSaving = true; defer { isSaving = false }
        try await store.saveSession(next)
        state = next
    }
    func move(by delta: Int, now: Date = .now) async throws {
        guard !isSaving else { throw ReviewSessionError.busy }
        guard var next = state else { throw ReviewSessionError.empty }
        // Only previous/next are navigation; these never mark an asset retained/deleted.
        guard delta == -1 || delta == 1 else { return }
        let cursor = next.cursor + delta
        guard next.assetIDs.indices.contains(cursor) else { return }
        next.cursor = cursor; next.updatedAt = now
        isSaving = true; defer { isSaving = false }
        try await store.saveSession(next)
        state = next
    }
    private func validate(_ value: SessionState) throws {
        guard !value.assetIDs.isEmpty, value.assetIDs.indices.contains(value.cursor),
              Set(value.assetIDs).count == value.assetIDs.count,
              value.assetIDs.allSatisfy({ !$0.isEmpty }) else { throw ReviewSessionError.invalidSession }
    }
}
