import SwiftUI

struct ReviewEntryView: View {
    let review: ReviewSession
    var favorites: FavoriteCoordinator? = nil
    var pending: PendingCoordinator? = nil
    @State private var actions: ReviewActions
    @State private var exiting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var usesReducedMotion: Bool {
        #if DEBUG
        reduceMotion || ProcessInfo.processInfo.arguments.contains("--reduced-motion-test")
        #else
        reduceMotion
        #endif
    }
    var onIntent: (ReviewIntent) -> Void = { _ in }
    @State private var loader = PhotoLoader()
    @State private var palette: PhotoPalette = .neutral
    private var loadedImageID: ObjectIdentifier? {
        if case .ready(let image) = loader.state { return ObjectIdentifier(image) }
        return nil
    }
    private var stateBackground: Bool {
        guard case .available(let asset) = review.current else { return true }
        if asset.kind == .video { return false }
        if case .ready = loader.state { return false }
        return true
    }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.displayScale) private var displayScale
    @State private var viewport = CGSize.zero
    private var compactToolbar: Bool { viewport.width > viewport.height && !typeSize.isAccessibilitySize }
    private var toolbarHeight: CGFloat {
        if typeSize.isAccessibilitySize {
            let available = viewport.width > viewport.height ? viewport.height * 0.45 : viewport.height - 120
            return min(360, max(140, available))
        }
        return (compactToolbar ? 70 : 132) + (review.endMessage != nil || actions.needsPositionRecovery ? 48 : 0)
    }
    init(review: ReviewSession, favorites: FavoriteCoordinator? = nil,
         pending: PendingCoordinator? = nil, onIntent: @escaping (ReviewIntent) -> Void = { _ in }) {
        self.review = review; self.favorites = favorites; self.pending = pending; self.onIntent = onIntent
        _actions = State(initialValue: ReviewActions(review: review, favorites: favorites, pending: pending))
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if stateBackground { PhotoPaletteBackground(palette: palette) }
                else { Color.black.ignoresSafeArea() }
                media(size: geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .offset(y: exiting && !usesReducedMotion ? -geometry.size.height : 0)
                    .scaleEffect(exiting && !usesReducedMotion ? 0.96 : 1)
                    .opacity(exiting ? 0 : 1)
                    .allowsHitTesting(!actions.pendingTransition)
                if let feedback = actions.feedback, !review.isComplete {
                    HStack(spacing: 12) {
                        Text(feedback).accessibilityIdentifier("review.feedback")
                        if actions.showsPendingUndo {
                            Button { Task { await actions.undo() } } label: {
                                Text("撤销").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(actionBusy)
                                .accessibilityIdentifier("review.feedback-undo")
                        }
                    }.font(.callout).padding(.horizontal, 12).padding(.vertical, 4).reviewControlGlass(light: stateBackground)
                        .padding(.bottom, controls ? toolbarHeight + 30 : 24)
                }
                if controls {
                    toolbar.disabled(actions.pendingTransition).frame(height: toolbarHeight).padding(.horizontal, 16).padding(.bottom, 12)
                    VStack {
                        HStack {
                            Button("返回回顾", systemImage: "xmark") { dismiss() }
                                .accessibilityIdentifier("review.back")
                            Spacer()
                            Button(scale > 1 ? "还原照片" : "放大照片", systemImage: scale > 1 ? "arrow.down.right.and.arrow.up.left" : "plus.magnifyingglass") {
                                scale = scale > 1 ? 1 : 2; baseScale = scale; offset = .zero; baseOffset = .zero; router.cancel()
                            }.disabled(!isPhoto || actionBusy).accessibilityIdentifier("review.zoom")
                        }.labelStyle(.iconOnly).buttonStyle(ReviewFloatingButtonStyle(light: stateBackground))
                        Spacer()
                    }.padding(.horizontal, 16).padding(.top, 12)
                }
            }
            .onChange(of: geometry.size, initial: true) { _, size in
                guard viewport != size else { return }
                viewport = size
                // Fit the complete photo in the new viewport; rotation never moves the session.
                scale = 1; baseScale = 1; offset = .zero; baseOffset = .zero; router.cancel()
                loadCurrent()
            }
        }
        .onChange(of: loadedImageID, initial: true) { _, _ in
            if case .ready(let image) = loader.state { palette = PhotoPalette.extract(from: image) }
        }
        .onAppear { actions.appear(); ReviewOrientation.setReviewActive(true) }
        .task(id: review.state?.assetIDs.last) { if let range = review.rangeTitle { actions.showFeedback("回顾范围：\(range)") } }
        .statusBarHidden(true)
        .task(id: review.currentID) { loadCurrent(); similarity.start(currentID: review.currentID, assets: review.snapshot.assets) }
        .onChange(of: review.snapshot.assets) { _, _ in loadCurrent(); similarity.start(currentID: review.currentID, assets: review.snapshot.assets) }
        .onChange(of: review.snapshot.permission) { _, _ in loadCurrent(); similarity.start(currentID: review.currentID, assets: review.snapshot.assets) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { similarity.start(currentID: review.currentID, assets: review.snapshot.assets) } else { similarity.pause() }
        }
        .task {
            await actions.prepare()
            if review.isComplete { controls = true }
        }
        .onChange(of: pending?.items) { _, _ in actions.synchronizePending() }
        .alert("这张照片已收藏，仍加入待删？", isPresented: Binding(get: { actions.favoritePendingID != nil }, set: { if !$0 { actions.dismissFavoriteConfirmation() } })) {
            if let id = actions.favoritePendingID {
                Button("仍加入待删", role: .destructive) { Task { await confirmPending(id) } }
            }
            Button("取消", role: .cancel) { actions.dismissFavoriteConfirmation() }
        } message: { Text("只加入待删记录，保留系统收藏。原片要在集中复核后才会删除。") }
        .onChange(of: review.currentID) { _, _ in scale = 1; baseScale = 1; offset = .zero; baseOffset = .zero; router.reset() }
        .onDisappear { actions.disappear(); exiting = false; loader.releaseMemory(); router.cancel(); similarity.pause(); ReviewOrientation.setReviewActive(false) }
        .sheet(item: $comparison) { selection in
            if let pending { ComparisonView(groups: selection.groups, assets: selection.assets, pending: pending) }
        }
        .alert("回顾位置未保存", isPresented: Binding(get: { actions.error != nil }, set: { if !$0 { actions.dismissError() } })) {
            Button("好", role: .cancel) { actions.dismissError() }
        } message: { Text(actions.error ?? "") }
        .alert("待删操作未完成", isPresented: Binding(get: { actions.pendingFailure != nil }, set: { if !$0 { actions.dismissPendingFailure() } })) {
            Button("好", role: .cancel) { actions.dismissPendingFailure() }
        } message: { Text(actions.pendingFailure ?? "") }
    }
    @ViewBuilder private func media(size: CGSize) -> some View {
        switch review.current {
        case .available(let asset):
            if asset.kind == .video {
                VideoReviewView(assetID: asset.id, showControls: controls, palette: palette,
                                onMediaDrag: { finish($0) }, onMediaDragChanged: { update($0) },
                                onMediaTap: { controls.toggle() }, controlsBottomInset: toolbarHeight + 24)
                    .id(asset.modificationDate)
            } else {
                ZStack {
                    switch loader.state {
                    case .ready(let image):
                        PhotoContentView(image: image).scaleEffect(scale).offset(offset)
                            .frame(width: size.width, height: size.height)
                    case .loading(let progress): photoLoading(progress)
                    case .offline: retry("当前离线，连接后重试")
                    case .needsDownload: retry("从 iCloud 加载照片")
                    case .failed, .unavailable: retry("照片暂不可用，重试")
                    case .idle: photoLoading(nil)
                    }
                }
                .frame(width: size.width, height: size.height).clipped().contentShape(Rectangle())
                .accessibilityElement(children: .contain)
                .accessibilityLabel("回顾照片")
                .accessibilityValue("第\((review.state?.cursor ?? 0) + 1)项，缩放\(Int(scale * 100))%")
                .accessibilityIdentifier("review.photo")
                .onTapGesture { controls.toggle() }
                .accessibilityAction(named: controls ? "收起回顾操作" : "显示回顾操作") { controls.toggle() }
                .gesture(drag(size: size))
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    pinching = true; router.cancel(); scale = min(4, max(1, baseScale * value.magnification))
                }.onEnded { _ in
                    baseScale = scale; pinching = false
                    if scale == 1 { offset = .zero; baseOffset = .zero }
                })
            }
        case .unavailable(let message):
            ScrollView {
                PhotoStatusCard(title: "当前项目不可用", message: message, icon: "photo.badge.exclamationmark", color: PhotoTheme.warning).padding(24)
            }.clipped().accessibilityIdentifier("review.state-scroll").padding(.top, 64).padding(.bottom, controls ? toolbarHeight + 24 : 24).photoPage()
                .frame(width: size.width, height: size.height).contentShape(Rectangle())
                .onTapGesture { controls.toggle() }
                .accessibilityAction(named: controls ? "收起回顾操作" : "显示回顾操作") { controls.toggle() }
                .gesture(drag(size: size))
        case .completed:
            ScrollView {
                VStack(spacing: compactToolbar ? 10 : 18) {
                    if compactToolbar {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle").font(.system(size: 24))
                            completionTitle
                        }
                    } else {
                        Image(systemName: "checkmark.circle").font(.system(size: 44))
                        completionTitle
                    }
                    Text(!actions.needsPositionRecovery ? "待删原片仍保留，可撤销或返回首页集中复核。" : "照片已保留，回顾位置尚未恢复。可重试或返回首页。")
                        .font(.callout).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    Button("返回回顾") { dismiss() }.buttonStyle(PhotoGlassButtonStyle()).accessibilityIdentifier("review.completed-back")
                }.padding(compactToolbar ? 16 : 24).photoGlass(radius: 30).padding(.horizontal, 24).photoPage()
                    .frame(maxWidth: .infinity, minHeight: max(0, size.height - toolbarHeight - 120))
            }.clipped().accessibilityIdentifier("review.completed-scroll").padding(.top, 72).padding(.bottom, toolbarHeight + 24)
                .frame(width: size.width, height: size.height)
        case .noSession:
            ScrollView {
                VStack(spacing: 20) {
                    PhotoStatusCard(title: "暂无回顾片段", message: "返回首页，选择一段时光。", icon: "photo.on.rectangle")
                    Button("返回回顾") { dismiss() }.buttonStyle(PhotoGlassButtonStyle())
                }.padding(24)
            }.clipped().accessibilityIdentifier("review.state-scroll").padding(.top, 64).padding(.bottom, controls ? toolbarHeight + 24 : 24).photoPage()
                .frame(width: size.width, height: size.height).contentShape(Rectangle())
                .onTapGesture { controls.toggle() }
                .accessibilityAction(named: controls ? "收起回顾操作" : "显示回顾操作") { controls.toggle() }
        }
    }
    private var completionTitle: some View {
        Text(!actions.needsPositionRecovery ? "本轮已看完" : "待删已撤回").font(.title2.bold()).accessibilityIdentifier("review.completed")
    }
    private var toolbar: some View {
        Group {
            if compactToolbar { landscapeToolbar }
            else { portraitToolbar }
        }
    }
    private var positionLabel: some View {
        VStack(spacing: 2) {
            if case .available(let asset) = review.current {
                Text(asset.creationDate.map { $0.formatted(.dateTime.year().month().day()) } ?? "日期未知")
            } else { Text(review.isComplete ? (!actions.needsPositionRecovery ? "本轮完成" : "待删已撤回") : "当前项目不可用") }
            Text(!actions.needsPositionRecovery ? "剩余 \(review.remainingCount) 项" : "位置待恢复")
                .monospacedDigit().accessibilityIdentifier("review.position")
#if DEBUG
                .accessibilityValue(ProcessInfo.processInfo.arguments.contains("--random-preview-test") ? review.state?.assetIDs.joined(separator: ",") ?? "" : "")
#endif
        }.font(.caption).multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
    private var navigationPill: some View {
        HStack(spacing: 8) {
            Button("上一项", systemImage: "chevron.left") { navigate(.previous) }
                .disabled(!review.canGoBack || review.isSaving || actionBusy)
            positionLabel
            Button("下一项", systemImage: "chevron.right") { navigate(.next) }
                .disabled(!review.canGoForward || review.isSaving || actionBusy)
        }.labelStyle(.iconOnly).buttonStyle(ReviewCompactButtonStyle())
            .padding(.horizontal, 6).padding(.vertical, 4).reviewControlGlass(light: stateBackground, radius: 30)
    }
    private var actionPill: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 8) {
            action(isFavorite ? "已收藏" : "收藏", icon: isFavorite ? "heart.fill" : "heart", kind: .favorite)
            action(pendingTitle, icon: "trash", kind: .pending)
            Button {
                comparison = ComparisonPresentation(groups: similarity.groups, assets: review.snapshot.assets)
            } label: { actionLabel("相似", icon: "rectangle.on.rectangle") }
                .accessibilityLabel(similarityLabel)
                .disabled(similarity.groups.isEmpty || pending == nil || actionBusy).accessibilityIdentifier("review.similar")
            Button { Task { await actions.undo() } } label: { actionLabel("撤销", icon: "arrow.uturn.backward") }
                .disabled(!actions.canUndo || actionBusy).accessibilityIdentifier("review.undo")
        }.font(.caption).buttonStyle(.plain).padding(.horizontal, 8).padding(.vertical, 8)
            .reviewControlGlass(light: stateBackground, radius: 26)
    }
    private func actionLabel(_ title: String, icon: String) -> some View {
        VStack(spacing: 4) { Image(systemName: icon).font(.title3); Text(title) }
            .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
    }
    private var portraitToolbar: some View {
        ScrollView {
            VStack(spacing: 10) { boundaryControl; navigationPill; actionPill }
        }.scrollIndicators(.hidden).accessibilityIdentifier("review.toolbar-scroll")
    }
    @ViewBuilder private var boundaryControl: some View {
        if actions.needsPositionRecovery {
            Button { Task { await actions.restorePosition() } } label: {
                Text("重试回到照片").frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).reviewControlGlass(light: stateBackground)
                .disabled(review.isSaving || actionBusy).accessibilityIdentifier("review.restore-position")
        } else if let message = review.endMessage {
            if review.nearbySegment != nil {
                Button {
                    Task { await actions.exploreNearby() }
                } label: {
                    Label(review.nearbyTitle, systemImage: "arrow.right").font(.callout).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).reviewControlGlass(light: stateBackground).disabled(review.isSaving || actionBusy).accessibilityIdentifier("review.nearby")
                    .accessibilityHint(message)
            } else { Text(message).font(.caption).padding(8).reviewControlGlass(light: stateBackground).accessibilityIdentifier("review.end") }
        }
    }
    private var landscapeToolbar: some View {
        VStack(spacing: 8) {
            boundaryControl
            HStack(spacing: 12) {
                navigationPill.frame(maxWidth: .infinity)
                actionPill.frame(maxWidth: .infinity)
            }
        }
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
    private func action(_ title: String, icon: String, kind: ReviewIntent.Kind, compact: Bool = false) -> some View {
        Button { if let id = review.currentID { emit(ReviewIntent(assetID: id, kind: kind)) } } label: {
            if compact { Image(systemName: icon).accessibilityLabel(title) }
            else { actionLabel(title, icon: icon) }
        }.disabled(review.isSaving || !isAvailable || actionBusy).accessibilityIdentifier("review.\(kind.rawValue)")
    }
    private var isAvailable: Bool { if case .available = review.current { return true }; return false }
    private func navigate(_ kind: ReviewIntent.Kind) {
        guard !review.isSaving, !actionBusy else { return }
        if kind == .next && !review.canGoForward && review.nearbySegment != nil { controls = true }
        Task { await actions.navigate(kind) }
    }
    private func emit(_ intent: ReviewIntent) {
        guard intent.assetID == review.currentID, !review.isSaving, !actionBusy else { return }
        if intent.kind == .next || intent.kind == .previous { navigate(intent.kind) }
        else if isAvailable {
            onIntent(intent)
            Task {
                let advanced = await actions.perform(intent, transition: animatePendingExit)
                finishPendingPresentation(advanced: advanced)
            }
        }
    }
    private var actionBusy: Bool { actions.isBusy }
    private var pendingTitle: String {
        guard let pending else { return "待删" }
        let count = DeletionReviewModel.readyCount(pending.items, assets: review.snapshot.assets)
        let unknown = pending.items.count - count
        return "待删 \(count)" + (unknown > 0 ? " · 待核对 \(unknown)" : "")
    }
    private func confirmPending(_ id: String) async {
        let advanced = await actions.confirmPending(id, transition: animatePendingExit)
        finishPendingPresentation(advanced: advanced)
    }
    private func animatePendingExit() async {
        withAnimation(.easeIn(duration: usesReducedMotion ? 0.16 : 0.28)) { exiting = true }
        try? await Task.sleep(for: .milliseconds(usesReducedMotion ? 170 : 290))
    }
    private func finishPendingPresentation(advanced: Bool) {
        if advanced {
            // Reveal the next frame only after populating its bounded cache.
            loadCurrent()
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { exiting = false }
            if review.isComplete { controls = true }
        } else { exiting = false }
    }
    private func update(_ translation: CGSize) {
        router.update(x: translation.width, y: translation.height, assetID: review.currentID, blocked: pinching || scale > 1 || review.isSaving || actionBusy)
    }
    private func finish(_ translation: CGSize) {
        if let intent = router.end(x: translation.width, y: translation.height, currentID: review.currentID, blocked: pinching || scale > 1 || review.isSaving || actionBusy) { emit(intent) }
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
        guard viewport.width > 0, viewport.height > 0, case .available(let asset) = review.current, asset.kind == .photo else { return }
        let neighbors = [-1, 1].compactMap { delta -> PhotoRequestKey? in
            guard let state = review.state, state.assetIDs.indices.contains(state.cursor + delta),
                  let neighbor = review.snapshot.assets.first(where: { $0.id == state.assetIDs[state.cursor + delta] && $0.kind == .photo }) else { return nil }
            return PhotoRequestKey(assetID: neighbor.id, version: neighbor.modificationDate, width: max(1, Int(viewport.width * displayScale)), height: max(1, Int(viewport.height * displayScale)))
        }
        loader.load(PhotoRequestKey(assetID: asset.id, version: asset.modificationDate, width: max(1, Int(viewport.width * displayScale)), height: max(1, Int(viewport.height * displayScale))), neighbors: neighbors)
    }
    private func photoLoading(_ progress: Double?) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
            Text("正在加载照片").font(.headline)
        }.padding(24).photoGlass().photoPage()
    }
    private func retry(_ title: String) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                PhotoStatusCard(title: "照片暂不可用", message: title, icon: "photo.badge.exclamationmark", color: PhotoTheme.warning)
                Button(title) { loader.retry() }.buttonStyle(PhotoGlassButtonStyle()).accessibilityIdentifier("review.photo-retry")
            }.padding(24)
        }.clipped().accessibilityIdentifier("review.state-scroll").padding(.top, 64).padding(.bottom, controls ? toolbarHeight + 24 : 24).photoPage()
    }
}

private struct ReviewCompactButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 44, height: 44).contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.35)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

private struct ReviewFloatingButtonStyle: ButtonStyle {
    var light = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 44, height: 44).contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.35).reviewControlGlass(light: light, radius: 24)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

private extension View {
    @ViewBuilder func reviewControlGlass(light: Bool, radius: CGFloat = 26) -> some View {
        if light { self.foregroundStyle(PhotoTheme.ink).tint(PhotoTheme.ink).photoGlass(radius: radius) }
        else { self.recollectionGlass(radius: radius) }
    }
}
