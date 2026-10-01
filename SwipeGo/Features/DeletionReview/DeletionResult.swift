import Foundation

/// Presentation is derived from the receipt, never from missing PhotoKit assets.
struct DeletionResult: Equatable {
    enum Outcome: Equatable { case succeeded, cancelled, failed, unknown, journalPending }
    let outcome: Outcome
    let count: Int
    var remaining: Int?
    var title: String {
        switch outcome {
        case .succeeded: "已删除 \(count) 项"
        case .cancelled: "已取消删除"
        case .failed: "请重新复核"
        case .unknown: "删除结果待核对"
        case .journalPending: "照片已删除，记录待核对"
        }
    }
    var detail: String {
        switch outcome {
        case .succeeded: "系统已确认删除本次清单。"
        case .cancelled: "已取消删除，待删记录仍保留。"
        case .failed: "内容或权限发生变化，未发起新的删除，请返回复核。"
        case .unknown: "结果暂不确定，记录已保留。请核对操作记录，不会自动重试。"
        case .journalPending: "系统已确认删除，但本地记录保存失败。记录仍需核对。"
        }
    }
    var remainingText: String {
        guard outcome == .succeeded else { return "待删记录仍保留，未自动清空" }
        guard let remaining else { return "剩余记录暂时无法读取，请返回核对" }
        return remaining == 0 ? "待删清单已清空" : "还有 \(remaining) 项待删记录"
    }
    init(_ result: DeletionCoordinator.Result, count: Int, remaining: Int? = nil) {
        self.count = count; self.remaining = remaining
        switch result {
        case .succeeded: outcome = .succeeded
        case .cancelled: outcome = .cancelled
        case .failed: outcome = .failed
        case .needsReview: outcome = .unknown
        case .succeededJournalPending: outcome = .journalPending
        }
    }
}
