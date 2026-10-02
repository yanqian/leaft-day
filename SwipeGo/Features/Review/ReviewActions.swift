import Foundation
import Observation

/// Owns the complete review action, including its partial-success recovery.
/// Rendering and animation belong to the caller; durable intent and cursor
/// writes remain in the existing coordinators and session.
@MainActor @Observable final class ReviewActions {
    private enum UndoKind { case favorite, pending }
    private var lastUndo: UndoKind?
    private var pendingUndoSessionID: UUID?
    private var pendingRestoreID: String?
    private var presentation = UUID()
    private var visible = false
    private var feedbackToken = UUID()
    private var performing = false
    private(set) var pendingTransition = false
    private(set) var favoritePendingID: String?
    private(set) var pendingFailure: String?
    private(set) var error: String?
    private(set) var feedback: String?

    @ObservationIgnored private let review: ReviewSession
    @ObservationIgnored private let favorites: FavoriteCoordinator?
    @ObservationIgnored private let pending: PendingCoordinator?
    @ObservationIgnored private let readSnapshot: @MainActor () async -> LibrarySnapshot

    init(review: ReviewSession, favorites: FavoriteCoordinator? = nil,
         pending: PendingCoordinator? = nil,
         readSnapshot: @escaping @MainActor () async -> LibrarySnapshot = { PhotoLibraryGateway().snapshot() }) {
        self.review = review; self.favorites = favorites; self.pending = pending
        self.readSnapshot = readSnapshot
    }

    var isBusy: Bool { performing || favorites?.isBusy == true || pending?.isBusy == true }
    var needsPositionRecovery: Bool { pendingRestoreID != nil }
    var canUndo: Bool {
        switch lastUndo {
        case .pending: pending?.undoRecord != nil
        case .favorite: favorites?.undoRecord != nil
        case nil: false
        }
    }
    var showsPendingUndo: Bool { lastUndo == .pending && canUndo }

    func appear() { visible = true; presentation = UUID() }
    func disappear() { visible = false; presentation = UUID() }
    func dismissFavoriteConfirmation() { favoritePendingID = nil }
    func dismissPendingFailure() { pendingFailure = nil }
    func dismissError() { error = nil }

    func prepare() async {
        do {
            try await pending?.reload()
            synchronizePending()
            if pending != nil { try await review.resumeAvoidingPending() }
        } catch { showFeedback("待删记录或回顾位置暂时无法读取，请重试") }
    }
    func synchronizePending() { if let pending { review.updatePending(pending.items) } }

    /// Returns whether a saved pending mark advanced the current frame. The
    /// transition callback only renders its exit animation; the action retains
    /// ownership of the busy interval and validates its target after suspension.
    @discardableResult
    func perform(_ intent: ReviewIntent, transition: @MainActor () async -> Void = {}) async -> Bool {
        guard intent.assetID == review.currentID, !review.isSaving, !isBusy else { return false }
        switch intent.kind {
        case .next, .previous: await navigate(intent.kind); return false
        case .favorite:
            guard case .available = review.current else { return false }
            await favorite(intent.assetID); return false
        case .pending:
            guard case .available = review.current else { return false }
            return await markPending(intent.assetID, confirmed: false, transition: transition)
        }
    }
    @discardableResult
    func confirmPending(_ id: String, transition: @MainActor () async -> Void = {}) async -> Bool {
        favoritePendingID = nil
        return await markPending(id, confirmed: true, transition: transition)
    }
    func navigate(_ kind: ReviewIntent.Kind) async {
        guard kind == .next || kind == .previous, !review.isSaving, !isBusy else { return }
        guard kind == .next ? review.canGoForward : review.canGoBack else {
            showFeedback(kind == .next ? "已经是这一段的最后一项" : "已经是这一段的第一项")
            return
        }
        performing = true; defer { performing = false }
        do { try await review.move(by: kind == .next ? 1 : -1); pendingRestoreID = nil }
        catch { self.error = "请重试，仍停留在原来的位置。" }
    }
    func exploreNearby() async {
        guard !review.isSaving, !isBusy else { return }
        performing = true; defer { performing = false }
        do { try await review.exploreNearby() }
        catch { self.error = "请重试，仍停留在原来的位置。" }
    }
    func undo() async {
        guard !isBusy, !review.isSaving else { return }
        performing = true; defer { performing = false }
        if lastUndo == .pending, let pending {
            do {
                let originalID = pending.undoRecord?.assetID
                try await pending.undo(); lastUndo = nil; synchronizePending()
                do {
                    if let originalID { try await review.returnToUnmarked(originalID, sessionID: pendingUndoSessionID) }
                    pendingRestoreID = nil
                    showFeedback("已撤回待删标记")
                } catch {
                    pendingRestoreID = originalID
                    pendingFailure = "已撤回待删标记，照片仍保留，但回顾位置未恢复。可重试回到照片。"
                }
            } catch { pendingFailure = "撤回未完成，请核对待删记录并重试。" }
        } else if lastUndo == .favorite {
            await undoFavorite()
            if favorites?.undoRecord == nil { lastUndo = nil }
        }
    }
    func restorePosition() async {
        guard let id = pendingRestoreID, !review.isSaving, !isBusy else { return }
        performing = true; defer { performing = false }
        do {
            try await review.returnToUnmarked(id, sessionID: pendingUndoSessionID)
            pendingRestoreID = nil
            showFeedback("已回到撤销的照片")
        } catch { pendingFailure = "待删标记已撤回，回顾位置仍未保存，请稍后重试。" }
    }
    func showFeedback(_ text: String) {
        let token = UUID(); feedbackToken = token; feedback = text
        let duration: Double = lastUndo == .pending ? 5 : 2
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            if self?.feedbackToken == token { self?.feedback = nil }
        }
    }

    private func markPending(_ id: String, confirmed: Bool,
                             transition: @MainActor () async -> Void) async -> Bool {
        guard let pending, !isBusy, !review.isSaving, let sessionID = review.state?.id,
              id == review.currentID else { return false }
        let origin = presentation
        performing = true; pendingTransition = true
        defer { performing = false; pendingTransition = false }
        do {
            let changed = try await pending.mark(id, confirmedFavorite: confirmed)
            if changed { lastUndo = .pending; pendingUndoSessionID = sessionID }
            synchronizePending()
            guard isCurrent(origin, assetID: id, sessionID: sessionID) else { return false }
            await transition()
            guard isCurrent(origin, assetID: id, sessionID: sessionID) else { return false }
            do {
                try await review.advanceAfterPending(assetID: id, sessionID: sessionID)
                pendingRestoreID = nil
                showFeedback(changed ? "已加入待删，原片仍保留" : "已跳过待删项目")
                return true
            } catch { showFeedback("已加入待删，但位置未保存。可重试待删按钮或撤销") }
        } catch PendingCoordinator.Failure.confirmFavorite { favoritePendingID = id }
        catch { showFeedback("待删标记未保存，请重试") }
        return false
    }
    private func isCurrent(_ origin: UUID, assetID: String, sessionID: UUID) -> Bool {
        visible && presentation == origin && !Task.isCancelled && review.currentID == assetID && review.state?.id == sessionID
    }
    private func favorite(_ id: String) async {
        guard let favorites else { return }
        performing = true; defer { performing = false }
        do {
            let result = try await favorites.favorite(id)
            if result.changed { lastUndo = result.journalSaved ? .favorite : nil }
            await refreshFacts()
            showFeedback(!result.journalSaved ? "已收藏，本地记录待核对" : result.changed ? (id == review.currentID ? "已收藏" : "已收藏刚才操作的照片") : "这张照片已收藏")
        } catch FavoriteError.cancelled { await refreshFacts(); showFeedback("已取消收藏操作") }
        catch FavoriteError.busy { }
        catch { await refreshFacts(); showFeedback("收藏未完成，请重试") }
    }
    private func refreshFacts() async {
        let origin = presentation
        let snapshot = await readSnapshot()
        guard presentation == origin else { return }
        review.updateLibrary(snapshot)
    }
    private func undoFavorite() async {
        guard let favorites else { return }
        do {
            let result = try await favorites.undo()
            await refreshFacts()
            showFeedback(result.journalSaved ? "已撤销收藏" : "收藏已还原，本地记录待核对")
        } catch FavoriteError.changed { await refreshFacts(); showFeedback("照片状态已变化，未覆盖新的收藏状态") }
        catch { await refreshFacts(); showFeedback("撤销未完成，请重试") }
    }
}
