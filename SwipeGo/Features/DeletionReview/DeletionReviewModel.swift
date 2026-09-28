import Foundation
import Observation

struct DeletionReviewRow: Identifiable, Equatable {
    let intent: PendingIntent
    let asset: PhotoAssetSnapshot?
    let keepers: [PhotoAssetSnapshot]
    let needsReview: Bool
    var id: String { intent.assetID }
}

struct FrozenDeletion: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let intents: [PendingIntent]
    let targets: [PhotoAssetSnapshot]
    let keepers: [PhotoAssetSnapshot]
    var scope: PhotoAccessScope = PhotoAccessScope(permission: .full)
}

@MainActor @Observable final class DeletionReviewModel {
    enum Failure: Error { case changed, unavailable, busy }
    private(set) var rows: [DeletionReviewRow] = []
    private(set) var isBusy = false
    let deletion: DeletionCoordinator
    private(set) var unresolvedCount = 0
    var error: String?
    var frozen: FrozenDeletion?
    @ObservationIgnored let store: any LocalStateRepository
    @ObservationIgnored private let reader: any PhotoAssetReading
    init(store: any LocalStateRepository, reader: any PhotoAssetReading = NativeFavoriteWriter()) { self.store = store; self.reader = reader; self.deletion = DeletionCoordinator(store: store) }
    var readyCount: Int { rows.filter { !$0.needsReview }.count }
    var needsReviewCount: Int { rows.count - readyCount }
    static func readyCount(_ intents: [PendingIntent], assets: [PhotoAssetSnapshot]) -> Int {
        let available = Set(assets.map(\.id))
        let protected = Set(intents.flatMap { $0.comparison?.keptIDs ?? [] })
        return intents.filter { available.contains($0.assetID) && !protected.contains($0.assetID) && Set($0.comparison?.keptIDs ?? []).isSubset(of: available) }.count
    }
    private func readRows() async throws -> [DeletionReviewRow] {
        let intents = try await store.pending()
        let protected = Set(intents.flatMap { $0.comparison?.keptIDs ?? [] })
        let ids = Set(intents.map(\.assetID)).union(protected)
        var assets: [String: PhotoAssetSnapshot] = [:]
        for id in ids.sorted() { assets[id] = try? await reader.asset(id: id) }
        return intents.map { intent in
            let keptIDs = intent.comparison?.keptIDs ?? []
            return DeletionReviewRow(intent: intent, asset: assets[intent.assetID], keepers: keptIDs.compactMap { assets[$0] },
                needsReview: assets[intent.assetID] == nil || keptIDs.contains { assets[$0] == nil } || protected.contains(intent.assetID))
        }
    }
    func refresh() async {
        guard !isBusy && !deletion.isBusy else { return }
        if let frozen, deletion.lastAttemptID == frozen.id { return }
        frozen = nil
        isBusy = true; defer { isBusy = false }
        do { rows = try await readRows(); unresolvedCount = try await store.operations().filter { $0.kind == .deletion && $0.requiresReview }.count; error = nil }
        catch { self.error = "待删记录暂时无法读取，请重试。" }
    }
    func retract(_ intent: PendingIntent) async {
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        frozen = nil
        do {
            try await store.removePending(ifMatching: intent)
            rows.removeAll { $0.intent == intent }
            do { rows = try await readRows(); unresolvedCount = try await store.operations().filter { $0.kind == .deletion && $0.requiresReview }.count; error = nil }
            catch { self.error = "已撤回这条标记，其余记录需要刷新核对。" }
        } catch { self.error = "记录可能已变化，撤回未完成，请刷新核对。" }
    }
    func freeze() async {
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        frozen = nil
        do {
            let unresolved = try await store.operations().filter { $0.kind == .deletion && $0.requiresReview }
            guard !unresolved.contains(where: { !Set($0.targetIDs).isDisjoint(with: rows.map(\.id)) }) else { throw Failure.changed }
            let scope = await reader.accessScope()
            let latest = try await readRows()
            guard scope.permission.canRead, await reader.accessScope() == scope else { throw Failure.changed }
            guard latest == rows else { rows = latest; throw Failure.changed }
            guard !latest.isEmpty, latest.allSatisfy({ !$0.needsReview }) else { throw Failure.unavailable }
            var seen = Set<String>()
            frozen = FrozenDeletion(id: UUID(), intents: latest.map(\.intent), targets: latest.compactMap(\.asset),
                keepers: latest.flatMap(\.keepers).filter { seen.insert($0.id).inserted }, scope: scope)
            error = nil
        } catch { self.error = "内容或授权范围可能已变化，请重新复核。" }
    }
}
