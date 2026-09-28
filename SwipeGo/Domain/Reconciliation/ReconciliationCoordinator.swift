import Foundation
import Observation

// Process-local activity is intentionally lost on restart; durable journal is authoritative.
@MainActor final class OperationActivity {
    static let shared = OperationActivity()
    var ids: Set<UUID> = []
}

struct ReconciliationRecord: Identifiable {
    let operation: OperationState
    let visible: [PhotoAssetSnapshot]
    var id: UUID { operation.id }
}

@MainActor @Observable final class ReconciliationCoordinator {
    private(set) var records: [ReconciliationRecord] = []
    private(set) var isBusy = false
    var error: String?
    @ObservationIgnored private let store: any LocalStateRepository
    @ObservationIgnored private let reader: any PhotoAssetReading
    @ObservationIgnored private let activity: OperationActivity
    private var refreshAgain = false
    init(store: any LocalStateRepository, reader: any PhotoAssetReading = NativeFavoriteWriter(), activity: OperationActivity = .shared) {
        self.store = store; self.reader = reader; self.activity = activity
    }
    func refresh() async {
        guard !isBusy else { refreshAgain = true; return }
        isBusy = true; defer { isBusy = false }
        repeat {
            refreshAgain = false
            do {
                let observed = try await store.operations()
                for original in observed where original.requiresReview && !activity.ids.contains(original.id) {
                    guard original.phase == .prepared || original.phase == .submitted else { continue }
                    var next = original; next.phase = .needsReview; next.updatedAt = .now
                    if next.kind == .deletion { next.deletionOutcome = .unknown }
                    // A delayed reconciliation must not overwrite a newer successful receipt.
                    _ = try await store.replaceOperation(ifMatching: original, with: next)
                }
                let pending = try await store.operations().filter { $0.requiresReview && !activity.ids.contains($0.id) }
                var result: [ReconciliationRecord] = []
                for operation in pending {
                    var visible: [PhotoAssetSnapshot] = []
                    for id in operation.targetIDs { if let asset = try? await reader.asset(id: id) { visible.append(asset) } }
                    result.append(ReconciliationRecord(operation: operation, visible: visible))
                }
                records = result; error = nil
            } catch { self.error = "操作记录暂时无法核对，原记录仍保留。请重试。" }
        } while refreshAgain
    }
    func acknowledge(_ record: ReconciliationRecord) async {
        guard !isBusy else { return }
        isBusy = true
        do {
            var next = record.operation; next.reviewedAt = .now; next.updatedAt = .now
            guard !activity.ids.contains(next.id), try await store.replaceOperation(ifMatching: record.operation, with: next) else { throw DeletionError.changed }
            records.removeAll { $0.id == next.id }; error = nil
        } catch { self.error = "记录已经变化或保存失败，请刷新后再核对。" }
        isBusy = false
        if refreshAgain { await refresh() }
    }
}
