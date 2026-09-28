import Foundation
import Observation

@MainActor @Observable final class PendingCoordinator {
    enum Failure: Error { case busy, confirmFavorite, noUndo, changed, invalidSelection }
    private(set) var items: [PendingIntent] = []
    private(set) var undoRecord: PendingIntent?
    private(set) var isBusy = false
    @ObservationIgnored private let store: any LocalStateRepository
    @ObservationIgnored private let reader: any PhotoAssetReading
    init(store: any LocalStateRepository, reader: any PhotoAssetReading = NativeFavoriteWriter()) {
        self.store = store; self.reader = reader
    }
    func reload() async throws { items = try await store.pending() }
    func contains(_ id: String?) -> Bool { items.contains { $0.assetID == id } }
    @discardableResult func mark(_ id: String, confirmedFavorite: Bool = false) async throws -> Bool {
        guard !isBusy else { throw Failure.busy }; isBusy = true; defer { isBusy = false }
        let before = try await store.pending()
        guard !before.contains(where: { $0.assetID == id }) else { items = before; return false }
        let asset = try await reader.asset(id: id)
        guard !asset.isFavorite || confirmedFavorite else { throw Failure.confirmFavorite }
        let intent = PendingIntent(assetID: id, groupID: nil, markedAt: .now)
        try await store.markPending(intent)
        // Publish only after durable save. Repeated marks preserve the original record.
        items = before + [intent]; undoRecord = intent
        return true
    }
    func undo() async throws {
        guard !isBusy else { throw Failure.busy }
        guard let record = undoRecord else { throw Failure.noUndo }
        isBusy = true; defer { isBusy = false }
        let current = try await store.pending()
        guard current.first(where: { $0.assetID == record.assetID }) == record else {
            items = current; undoRecord = nil; throw Failure.changed
        }
        try await store.removePending(assetID: record.assetID)
        items = current.filter { $0.assetID != record.assetID }; undoRecord = nil
    }
    @discardableResult
    func compare(_ assets: [PhotoAssetSnapshot], keeping: Set<String>) async throws -> Int {
        guard !isBusy else { throw Failure.busy }
        let ids = assets.map(\.id)
        guard assets.count >= 2, Set(ids).count == ids.count, !keeping.isEmpty,
              keeping.isSubset(of: Set(ids)), assets.allSatisfy({ $0.kind == .photo }) else { throw Failure.invalidSelection }
        isBusy = true; defer { isBusy = false }
        for expected in assets {
            let latest = try await reader.asset(id: expected.id)
            guard latest == expected else { throw Failure.changed }
            guard !latest.isFavorite || keeping.contains(latest.id) else { throw Failure.confirmFavorite }
        }
        let kept = ids.filter { keeping.contains($0) }
        let context = ComparisonContext(assetIDs: ids, keptIDs: kept)
        let groupID = UUID().uuidString; let date = Date.now
        let values = ids.filter { !keeping.contains($0) }.map {
            PendingIntent(assetID: $0, groupID: groupID, markedAt: date, comparison: context)
        }
        let before = try await store.pending()
        try await store.saveComparison(values, keeping: kept)
        undoRecord = nil
        items = before.filter { !ids.contains($0.assetID) } + values
        return values.count
    }
}
