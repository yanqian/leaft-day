import SwiftUI

struct ReviewEntryView: View {
    let review: ReviewSession
    var favorites: FavoriteCoordinator? = nil
    var pending: PendingCoordinator? = nil
    private enum UndoKind { case favorite, pending }
    @State private var lastUndo: UndoKind?
    @State private var favoritePendingID: String?
    var onIntent: (ReviewIntent) -> Void = { _ in }
    @State private var loader = PhotoLoader()
    @State private var similarity = SimilarityModel()
    private struct ComparisonPresentation: Identifiable {
        let id = UUID()
        let groups: [SimilarityGroup]
        let assets: [PhotoAssetSnapshot]
    }
    @State private var comparison: ComparisonPresentation?
    @Environment(\.scenePhase) private var scenePhase
    @State private var controls = false
    @State private var router = ReviewGestureRouter()
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var baseOffset = CGSize.zero
    @State private var pinching = false
    @State private var error: String?
    @State private var feedback: String?
    @State private var feedbackToken = UUID()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    private var toolbarHeight: CGFloat { typeSize.isAccessibilitySize ? 360 : 190 }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                media(size: geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                VStack {
                    Button { controls.toggle() } label: { Color.clear.contentShape(Rectangle()) }
                        .frame(height: min(150, geometry.size.height * 0.2))
                        .accessibilityLabel(controls ? "收起回顾操作" : "显示回顾操作")
                        .accessibilityHint("点按画面上部，在底部展开操作")
                        .accessibilityIdentifier("review.toggle")
                        .simultaneousGesture(drag(size: geometry.size))
                    Spacer()
                }
                if let feedback {
                    Text(feedback).font(.callout).padding(12).glassPanel().padding(.bottom, controls ? toolbarHeight + 30 : 24)
                        .accessibilityIdentifier("review.feedback").allowsHitTesting(false)
                }
                if controls {
                    toolbar.frame(height: toolbarHeight).padding(.horizontal, 12).padding(.bottom, 12)
                }
            }
        }
        .statusBarHidden(true)
        .task(id: review.currentID) { loadCurrent(); similarity.start(currentID: review.currentID, assets: review.snapshot.assets) }
        .onChange(of: review.snapshot.assets) { _, _ in loadCurrent(); similarity.start(currentID: review.currentID, assets: review.snapshot.assets) }
        .onChange(of: review.snapshot.permission) { _, _ in loadCurrent(); similarity.start(currentID: review.currentID, assets: review.snapshot.assets) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { similarity.start(currentID: review.currentID, assets: review.snapshot.assets) } else { similarity.pause() }
        }
        .task { do { try await pending?.reload() } catch { showFeedback("待删记录暂时无法读取，请重试") } }
        .alert("这张照片已收藏，仍加入待删？", isPresented: Binding(get: { favoritePendingID != nil }, set: { if !$0 { favoritePendingID = nil } })) {
            if let id = favoritePendingID { Button("仍加入待删", role: .destructive) { favoritePendingID = nil; Task { await markPending(id, confirmed: true) } } }
            Button("取消", role: .cancel) { favoritePendingID = nil }
        } message: { Text("只加入待删记录，保留系统收藏。原片要在集中复核后才会删除。") }
        .onChange(of: review.currentID) { _, _ in scale = 1; baseScale = 1; offset = .zero; baseOffset = .zero; router.reset() }
        .onDisappear { loader.releaseMemory(); router.cancel(); similarity.pause() }
        .sheet(item: $comparison) { selection in
            if let pending { ComparisonView(groups: selection.groups, assets: selection.assets, pending: pending) }
        }
        .alert("回顾位置未保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
    @ViewBuilder private func media(size: CGSize) -> some View {
        switch review.current {
        case .available(let asset):
            if asset.kind == .video {
                VideoReviewView(assetID: asset.id, showControls: controls,
                                onMediaDrag: { finish($0) }, onMediaDragChanged: { update($0) })
                    .id(asset.modificationDate)
                    .padding(.bottom, controls ? toolbarHeight + 24 : 0)
            } else {
                ZStack {
                    switch loader.state {
                    case .ready(let image):
                        PhotoContentView(image: image).scaleEffect(scale).offset(offset)
                            .frame(width: size.width, height: size.height)
                    case .loading(let progress): ProgressView(value: progress).tint(.white)
                    case .offline: retry("当前离线，连接后重试")
                    case .needsDownload: retry("从 iCloud 加载照片")
                    case .failed, .unavailable: retry("照片暂不可用，重试")
                    case .idle: ProgressView().tint(.white)
                    }
                }
                .frame(width: size.width, height: size.height).clipped().contentShape(Rectangle())
                .accessibilityElement(children: .contain)
                .accessibilityLabel("回顾照片")
                .accessibilityValue("第\((review.state?.cursor ?? 0) + 1)项，缩放\(Int(scale * 100))%")
                .accessibilityIdentifier("review.photo")
                .gesture(drag(size: size))
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    pinching = true; router.cancel(); scale = min(4, max(1, baseScale * value.magnification))
                }.onEnded { _ in
                    baseScale = scale; pinching = false
                    if scale == 1 { offset = .zero; baseOffset = .zero }
                })
            }
        case .unavailable(let message): Text(message).foregroundStyle(.white).padding().gesture(drag(size: size))
        case .noSession: Text("暂无回顾片段").foregroundStyle(.white)
        }
    }
    private var toolbar: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Button("返回回顾", systemImage: "chevron.left") { dismiss() }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("review.back")
                    VStack(alignment: .leading) {
                        if case .available(let asset) = review.current {
                            Text(asset.creationDate.map { $0.formatted(.dateTime.year().month().day()) } ?? "日期未知")
                        } else { Text("当前项目不可用") }
                        Text("\((review.state?.cursor ?? 0) + 1) / \(review.state?.assetIDs.count ?? 0)")
                            .accessibilityIdentifier("review.position")
                    }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    Button(scale > 1 ? "还原照片" : "放大照片", systemImage: scale > 1 ? "arrow.down.right.and.arrow.up.left" : "plus.magnifyingglass") {
                        scale = scale > 1 ? 1 : 2; baseScale = scale; offset = .zero; baseOffset = .zero; router.cancel()
                    }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        .disabled(!isPhoto).accessibilityIdentifier("review.zoom")
                }
                HStack {
                    Button("上一项", systemImage: "chevron.left") { navigate(.previous) }.disabled(!review.canGoBack || review.isSaving)
                    Spacer()
                    Button("下一项", systemImage: "chevron.right") { navigate(.next) }.disabled(!review.canGoForward || review.isSaving)
                }.font(.caption).buttonStyle(.glass)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 2 : 4)) {
                    action(isFavorite ? "已收藏" : "收藏", icon: isFavorite ? "heart.fill" : "heart", kind: .favorite)
                    action(pending?.contains(review.currentID) == true ? "已待删" : "待删", icon: "trash", kind: .pending)
                    Button(similarityLabel, systemImage: "rectangle.on.rectangle") {
                        comparison = ComparisonPresentation(groups: similarity.groups, assets: review.snapshot.assets)
                    }.disabled(similarity.groups.isEmpty || pending == nil || actionBusy).accessibilityIdentifier("review.similar")
                    Button("撤销", systemImage: "arrow.uturn.backward") { Task { await undoLastAction() } }.disabled(!canUndo || actionBusy).accessibilityIdentifier("review.undo")
                }.font(.caption)
            }.padding(14)
        }.scrollIndicators(.hidden).glassPanel(radius: 26)
    }
    private var isFavorite: Bool { if case .available(let asset) = review.current { return asset.isFavorite }; return false }
    private var similarityLabel: String {
        switch similarity.state {
        case .analyzing: "分析中"
        case .failed: "分析不可用"
        case .ready: similarity.groups.isEmpty ? "暂无相似" : "相似 \(similarity.groups.count)"
        default: "相似"
        }
    }
    private var isPhoto: Bool { if case .available(let asset) = review.current { return asset.kind == .photo }; return false }
    private func action(_ title: String, icon: String, kind: ReviewIntent.Kind) -> some View {
        Button { if let id = review.currentID { emit(ReviewIntent(assetID: id, kind: kind)) } } label: {
            VStack(spacing: 5) { Image(systemName: icon).font(.title3); Text(title) }.frame(maxWidth: .infinity, minHeight: 44)
        }.disabled(review.isSaving || !isAvailable || actionBusy).accessibilityIdentifier("review.\(kind.rawValue)")
    }
    private var isAvailable: Bool { if case .available = review.current { return true }; return false }
    private func navigate(_ kind: ReviewIntent.Kind) { if let id = review.currentID { emit(ReviewIntent(assetID: id, kind: kind)) } }
    private func emit(_ intent: ReviewIntent) {
        guard intent.assetID == review.currentID, !review.isSaving else { return }
        if intent.kind == .next || intent.kind == .previous {
            Task { do { try await review.move(by: intent.kind == .next ? 1 : -1) } catch { self.error = "请重试，仍停留在原来的位置。" } }
        } else if isAvailable {
            guard !actionBusy else { return }
            onIntent(intent)
            if intent.kind == .favorite, let favorites {
                Task {
                    do {
                        let result = try await favorites.favorite(intent.assetID)
                        if result.changed { lastUndo = result.journalSaved ? .favorite : nil }
                        await refreshFacts()
                        showFeedback(!result.journalSaved ? "已收藏，本地记录待核对" : result.changed ? (intent.assetID == review.currentID ? "已收藏" : "已收藏刚才操作的照片") : "这张照片已收藏")
                    } catch FavoriteError.cancelled { await refreshFacts(); showFeedback("已取消收藏操作") }
                    catch FavoriteError.busy { }
                    catch { await refreshFacts(); showFeedback("收藏未完成，请重试") }
                }
            }
            if intent.kind == .pending, pending != nil { Task { await markPending(intent.assetID) } }
        }
    }
    private var actionBusy: Bool { favorites?.isBusy == true || pending?.isBusy == true }
    private var canUndo: Bool {
        switch lastUndo {
        case .pending: pending?.undoRecord != nil
        case .favorite: favorites?.undoRecord != nil
        case nil: false
        }
    }
    private func markPending(_ id: String, confirmed: Bool = false) async {
        guard let pending, !actionBusy else { return }
        do {
            let changed = try await pending.mark(id, confirmedFavorite: confirmed)
            if changed { lastUndo = .pending }
            showFeedback(changed ? "已加入待删，原片仍保留" : "已经在待删中")
        } catch PendingCoordinator.Failure.confirmFavorite { favoritePendingID = id }
        catch { showFeedback("待删标记未保存，请重试") }
    }
    private func undoLastAction() async {
        guard !actionBusy else { return }
        if lastUndo == .pending, let pending {
            do { try await pending.undo(); lastUndo = nil; showFeedback("已撤回待删标记") }
            catch { showFeedback("撤回未完成，请核对待删记录") }
        } else if lastUndo == .favorite { await undoFavorite(); if favorites?.undoRecord == nil { lastUndo = nil } }
    }
    private func refreshFacts() async { review.updateLibrary(await PhotoLibraryGateway().snapshot()) }
    private func undoFavorite() async {
        guard let favorites else { return }
        do {
            let result = try await favorites.undo()
            await refreshFacts()
            showFeedback(result.journalSaved ? "已撤销收藏" : "收藏已还原，本地记录待核对")
        } catch FavoriteError.changed { await refreshFacts(); showFeedback("照片状态已变化，未覆盖新的收藏状态") }
        catch { await refreshFacts(); showFeedback("撤销未完成，请重试") }
    }
    private func showFeedback(_ text: String) {
        let token = UUID(); feedbackToken = token; feedback = text
        Task { try? await Task.sleep(for: .seconds(2)); if feedbackToken == token { feedback = nil } }
    }
    private func update(_ translation: CGSize) {
        router.update(x: translation.width, y: translation.height, assetID: review.currentID, blocked: pinching || scale > 1 || review.isSaving)
    }
    private func finish(_ translation: CGSize) {
        if let intent = router.end(x: translation.width, y: translation.height, currentID: review.currentID, blocked: pinching || scale > 1 || review.isSaving) { emit(intent) }
    }
    private func drag(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 18).onChanged { value in
            if scale > 1 && !pinching {
                offset = CGSize(width: min(size.width * (scale - 1) / 2, max(-size.width * (scale - 1) / 2, baseOffset.width + value.translation.width)),
                                height: min(size.height * (scale - 1) / 2, max(-size.height * (scale - 1) / 2, baseOffset.height + value.translation.height)))
            }
            update(value.translation)
        }.onEnded { value in baseOffset = offset; finish(value.translation) }
    }
    private func loadCurrent() {
        loader.cancel()
        guard case .available(let asset) = review.current, asset.kind == .photo else { return }
        let neighbors = [-1, 1].compactMap { delta -> PhotoRequestKey? in
            guard let state = review.state, state.assetIDs.indices.contains(state.cursor + delta),
                  let neighbor = review.snapshot.assets.first(where: { $0.id == state.assetIDs[state.cursor + delta] && $0.kind == .photo }) else { return nil }
            return PhotoRequestKey(assetID: neighbor.id, version: neighbor.modificationDate, width: 1600, height: 2400)
        }
        loader.load(PhotoRequestKey(assetID: asset.id, version: asset.modificationDate, width: 1600, height: 2400), neighbors: neighbors)
    }
    private func retry(_ title: String) -> some View { Button(title) { loader.retry() }.buttonStyle(.glass).padding() }
}
