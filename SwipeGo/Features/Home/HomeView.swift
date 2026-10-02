import SwiftUI

@MainActor @Observable final class HomeModel {
    let store: any LocalStateRepository
    let review: ReviewSession
    let favorites: FavoriteCoordinator
    let pending: PendingCoordinator
    let reconciliation: ReconciliationCoordinator
    var presentingReconciliation = false
    let timeline = ReviewTimeline()
    let cache = PhotoMemoryCache(byteLimit: 12 * 1024 * 1024, countLimit: 6)
    let heroCover = HomeCoverLoader(cache: PhotoMemoryCache(byteLimit: 8 * 1024 * 1024, countLimit: 2))
    var presentingReview = false
    var presentingDeletionReview = false
    var pendingReadError = false
    var message: String?
    private(set) var randomSegment: ReviewSegment?
    private var visitedRandomSegment: ReviewSegment?
    init(store: any LocalStateRepository, assetScope: Set<String>? = nil) { self.store = store; review = ReviewSession(store: store, assetScope: assetScope); favorites = FavoriteCoordinator(store: store); pending = PendingCoordinator(store: store); reconciliation = ReconciliationCoordinator(store: store) }
    func reloadPending() async {
        do { try await pending.reload(); review.updatePending(pending.items); pendingReadError = false } catch { pendingReadError = true }
    }
    func updateLibrary(_ snapshot: LibrarySnapshot) {
        review.updateLibrary(snapshot)
        refreshRandomPreview()
    }
    private func refreshRandomPreview(avoiding previous: ReviewSegment? = nil) {
        guard review.snapshot.permission.canRead else { randomSegment = nil; return }
        let assets = review.snapshot.assets
        let byID = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if previous == nil, let selected = randomSegment,
           selected.assetIDs.allSatisfy({ byID[$0] != nil }) {
            // Preserve membership on ordinary refresh while updating dates and
            // cover asset versions from the current authorized snapshot.
            randomSegment = timeline.batch(selected.assetIDs.compactMap { byID[$0] })
            return
        }
        var rng = SystemRandomNumberGenerator()
        randomSegment = timeline.random(in: assets, using: &rng, avoiding: previous)
    }
    func reviewDidDismiss() {
        presentingReview = false
        guard let visited = visitedRandomSegment else { return }
        visitedRandomSegment = nil
        refreshRandomPreview(avoiding: visited)
    }
    var anniversary: ReviewSegment? { timeline.lastYearToday(in: review.snapshot.assets) }
    var initialSegment: ReviewSegment? { timeline.recent(in: review.snapshot.assets) }
    var heroSegment: ReviewSegment? {
        guard let state = review.state else { return initialSegment }
        let start = state.assetIDs.first.flatMap { id in review.snapshot.assets.first { $0.id == id }?.creationDate }
        let end = state.assetIDs.last.flatMap { id in review.snapshot.assets.first { $0.id == id }?.creationDate }
        return ReviewSegment(assetIDs: state.assetIDs, start: start, end: end)
    }
    func coverCandidates(_ segment: ReviewSegment?) -> [PhotoAssetSnapshot] {
        guard let segment else { return [] }
        let photos = Dictionary(uniqueKeysWithValues: review.snapshot.assets.filter { $0.kind == .photo }.map { ($0.id, $0) })
        return Array(segment.assetIDs.lazy.compactMap { photos[$0] }.prefix(3))
    }
    @discardableResult func open(_ segment: ReviewSegment?, mode: ReviewMode = .continuous) async -> Bool {
        guard let segment else { message = "这段时光暂无可回顾内容。"; return false }
        do { try await review.start(segment, mode: mode); presentingReview = true; return true }
        catch { message = "无法保存回顾位置，请重试。"; return false }
    }
    func resume() async {
        if review.state != nil {
            do { try await review.enableLegacyContinuation(); try await review.resumeAvoidingPending(); presentingReview = true }
            catch { message = "无法保存回顾位置，请重试。" }
        } else { await open(initialSegment) }
    }
    func random() async {
        guard !presentingReview else { return }
        let selected = randomSegment
        if await open(selected) { visitedRandomSegment = selected }
    }
}

struct HomeView: View {
    let snapshot: LibrarySnapshot
    let settings: () -> Void
    var storeOverride: (any LocalStateRepository)? = nil
    var assetScope: Set<String>? = nil
    @State private var model: HomeModel?
    @State private var storageError: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        GeometryReader { geometry in
        ZStack {
            PhotoColorBackdrop(image: model?.heroCover.image)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("日叶").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                            WrappingCaption(text: "留一点时间，看看过去")
                        }.accessibilityElement(children: .combine)
                        Spacer()
                        Button(action: settings) {
                            Image(systemName: "gearshape").font(.system(size: 20)).frame(width: 44, height: 44).contentShape(Circle())
                        }.buttonStyle(.plain).photoGlass(radius: 26).accessibilityLabel("设置")
                            .accessibilityIdentifier("home.settings")
                    }
                    if let model {
                        if snapshot.assets.isEmpty && model.review.state == nil {
                            ContentUnavailableView("等一段时光", systemImage: "photo.on.rectangle.angled", description: Text(snapshot.emptyMessage))
                                .frame(maxWidth: .infinity).padding(.vertical, 28).photoGlass()
                        } else { hero(model, height: heroHeight(model, available: geometry.size.height)) }
                        if typeSize.isAccessibilitySize {
                            anniversary(model, height: cardHeight(geometry.size.height)); random(model, height: cardHeight(geometry.size.height))
                        } else { HStack(alignment: .top, spacing: 12) { anniversary(model, height: cardHeight(geometry.size.height)); random(model, height: cardHeight(geometry.size.height)) } }
                        if !model.reconciliation.records.isEmpty || model.reconciliation.error != nil {
                            Button { model.presentingReconciliation = true } label: {
                                Text(model.reconciliation.error == nil ? "有 \(model.reconciliation.records.count) 项操作待核对" : "操作记录需要核对")
                                    .font(.footnote).frame(minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(PhotoGlassButtonStyle()).accessibilityIdentifier("home.reconciliation")
                        }
                        if snapshot.permission == .limited {
                            Text("仅在你选择的照片范围内回顾").font(.footnote).foregroundStyle(PhotoTheme.secondary)
                        }
                        Spacer(minLength: 0)
                        pendingCard(model)
                    } else if let storageError {
                        PhotoStatusCard(title: "暂时无法读取回顾", message: storageError, icon: "exclamationmark.circle")
                        Button("重试") { Task { await prepare() } }.buttonStyle(PhotoGlassButtonStyle())
                    } else { ProgressView("正在读取回顾位置") }
                }.frame(minHeight: max(0, geometry.size.height - 48), alignment: .top)
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 28).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.accessibilityIdentifier("home.scroll")
        }.photoPage()
        }
        .task { await prepare() }
        .task(id: heroCandidates) { model?.heroCover.load(heroCandidates) }
        .onDisappear { model?.heroCover.cancel() }
        .onChange(of: snapshot.assets) { _, _ in model?.updateLibrary(snapshot); Task { await model?.reconciliation.refresh(); await model?.reloadPending() } }
        .onChange(of: snapshot.permission) { _, _ in model?.updateLibrary(snapshot); Task { await model?.reconciliation.refresh(); await model?.reloadPending() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model?.reconciliation.refresh(); await model?.reloadPending() } } }
        .sheet(isPresented: Binding(get: { model?.presentingReconciliation ?? false }, set: { model?.presentingReconciliation = $0 })) {
            if let model { ReconciliationView(model: model.reconciliation) }
        }
        .fullScreenCover(isPresented: Binding(get: { model?.presentingReview ?? false }, set: { model?.presentingReview = $0 }), onDismiss: { ReviewOrientation.setReviewActive(false); model?.reviewDidDismiss(); Task { await model?.reloadPending(); await model?.reconciliation.refresh() } }) {
            if let model { ReviewEntryView(review: model.review, favorites: model.favorites, pending: model.pending) }
        }
        .sheet(isPresented: Binding(get: { model?.presentingDeletionReview ?? false }, set: { model?.presentingDeletionReview = $0 }), onDismiss: { Task { await model?.reloadPending(); await model?.reconciliation.refresh() } }) {
            if let model { DeletionReviewView(model: DeletionReviewModel(store: model.store), snapshot: snapshot) }
        }
        .alert("回顾提示", isPresented: Binding(get: { model?.message != nil }, set: { if !$0 { model?.message = nil } })) {
            Button("好", role: .cancel) { model?.message = nil }
        } message: { Text(model?.message ?? "") }
    }
    private func cardHeight(_ available: CGFloat) -> CGFloat {
        typeSize.isAccessibilitySize ? 320 : max(180, min(238, available * 0.31))
    }
    private func heroHeight(_ model: HomeModel, available: CGFloat) -> CGFloat {
        if typeSize.isAccessibilitySize { return 380 }
        let noticeHeight: CGFloat = (snapshot.permission == .limited ? 34 : 0)
            + ((!model.reconciliation.records.isEmpty || model.reconciliation.error != nil) ? 58 : 0)
        return max(170, min(360, available - cardHeight(available) - 238 - noticeHeight))
    }
    private func pendingCard(_ model: HomeModel) -> some View {
        Button { model.presentingDeletionReview = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash").font(.title3)
                Text(pendingTitle(model)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption)
            }.font(.subheadline).padding(.horizontal, 18).padding(.vertical, 8)
                .frame(minHeight: 52).frame(maxWidth: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 26))
        }.buttonStyle(.plain).photoGlass().accessibilityIdentifier("home.pending")
    }
    private var heroCandidates: [PhotoAssetSnapshot] { model.map { $0.coverCandidates($0.heroSegment) } ?? [] }
    private func prepare() async {
        guard model == nil else { model?.updateLibrary(snapshot); return }
        do {
            let paths = try LocalStoragePaths.application()
            let created = HomeModel(store: try storeOverride ?? LocalStateStore(url: paths.intentStore), assetScope: assetScope)
            created.updateLibrary(snapshot)
            try await created.review.restore()
            await created.reloadPending()
            await created.reconciliation.refresh()
            model = created; storageError = nil
        } catch { storageError = "回顾记录暂时无法读取，已有记录会保留。" }
    }
    private func pendingTitle(_ model: HomeModel) -> String {
        if model.pendingReadError { return "待删记录 · 读取失败" }
        let ready = DeletionReviewModel.readyCount(model.pending.items, assets: snapshot.assets)
        let unknown = model.pending.items.count - ready
        return "待删 \(ready) 项" + (unknown > 0 ? " · 待核对 \(unknown) 项" : "")
    }
    private func hero(_ model: HomeModel, height: CGFloat) -> some View {
        Button { Task { await model.resume() } } label: {
            HomeHeroCardContent(state: model.heroCover.state,
                title: model.heroSegment?.title(calendar: model.timeline.calendar) ?? "一段时光",
                summary: heroSummary(model), action: model.review.state == nil ? "开始回顾" : "继续回顾", minimumHeight: height)
        }.buttonStyle(.plain).accessibilityIdentifier("home.continue")
    }
    private func heroSummary(_ model: HomeModel) -> String {
        model.review.state == nil ? "\(model.heroSegment?.assetIDs.count ?? 0)项照片与视频"
            : model.review.isComplete ? "本轮已看完" : "剩余 \(model.review.remainingCount) 项"
    }
    private func anniversary(_ model: HomeModel, height: CGFloat) -> some View {
        Button { Task { await model.open(model.anniversary, mode: .anniversary) } } label: {
            smallCard("去年的今天", subtitle: model.anniversary == nil ? "这一天暂无内容" : "再看这一日", candidates: model.coverCandidates(model.anniversary), model: model, emptyText: "这一天暂无照片", height: height)
        }.buttonStyle(.plain).accessibilityIdentifier("home.anniversary")
    }
    private func random(_ model: HomeModel, height: CGFloat) -> some View {
        Button { Task { await model.random() } } label: {
            smallCard("随机时光", subtitle: "走进一段连续回忆", candidates: model.coverCandidates(model.randomSegment), model: model, emptyText: "走进一段时光", height: height)
        }.buttonStyle(.plain).disabled(model.randomSegment == nil).accessibilityIdentifier("home.random")
#if DEBUG
            .accessibilityValue(ProcessInfo.processInfo.arguments.contains("--random-preview-test")
                ? (model.randomSegment?.assetIDs.joined(separator: ",") ?? "") + ";covers=" + model.coverCandidates(model.randomSegment).map(\.id).joined(separator: ",") : "")
#endif
    }
    private func smallCard(_ title: String, subtitle: String, candidates: [PhotoAssetSnapshot], model: HomeModel, emptyText: String, height: CGFloat) -> some View {
        HomeArtwork(candidates: candidates, cache: model.cache, title: title, subtitle: subtitle, emptyText: emptyText, height: height)
    }
}
