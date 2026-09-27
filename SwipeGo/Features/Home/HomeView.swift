import SwiftUI

@MainActor @Observable final class HomeModel {
    let review: ReviewSession
    let favorites: FavoriteCoordinator
    let pending: PendingCoordinator
    let timeline = ReviewTimeline()
    let cache = PhotoMemoryCache(byteLimit: 12 * 1024 * 1024, countLimit: 6)
    var presentingReview = false
    var message: String?
    init(store: any LocalStateRepository) { review = ReviewSession(store: store); favorites = FavoriteCoordinator(store: store); pending = PendingCoordinator(store: store) }
    var segments: [ReviewSegment] { timeline.segments(in: review.snapshot.assets) }
    var anniversary: ReviewSegment? { timeline.lastYearToday(in: review.snapshot.assets) }
    var initialSegment: ReviewSegment? { segments.last(where: { $0.start != nil }) ?? segments.last }
    var heroSegment: ReviewSegment? {
        guard let state = review.state else { return initialSegment }
        let dates = state.assetIDs.compactMap { id in review.snapshot.assets.first { $0.id == id }?.creationDate }
        return ReviewSegment(assetIDs: state.assetIDs, start: dates.first, end: dates.last)
    }
    func cover(_ segment: ReviewSegment?) -> PhotoAssetSnapshot? {
        guard let segment else { return nil }
        return segment.assetIDs.lazy.compactMap { id in self.review.snapshot.assets.first { $0.id == id && $0.kind == .photo } }.first
    }
    func open(_ segment: ReviewSegment?) async {
        guard let segment else { message = "这段时光暂无可回顾内容。"; return }
        do { try await review.start(segment); presentingReview = true } catch { message = "无法保存回顾位置，请重试。" }
    }
    func resume() async {
        if review.state != nil { presentingReview = true } else { await open(initialSegment) }
    }
    func random() async {
        var rng = SystemRandomNumberGenerator()
        await open(timeline.random(in: review.snapshot.assets, using: &rng))
    }
}

struct HomeView: View {
    let snapshot: LibrarySnapshot
    let settings: () -> Void
    @State private var model: HomeModel?
    @State private var storageError: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ZStack {
            RecollectionBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("回顾").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                            WrappingCaption(text: "留一点时间，看看过去")
                        }.accessibilityElement(children: .combine)
                        Spacer()
                        Button("设置", systemImage: "gearshape") { settings() }
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).glassPanel(radius: 30)
                            .accessibilityIdentifier("home.settings")
                    }
                    if let model {
                        if snapshot.assets.isEmpty && model.review.state == nil {
                            ContentUnavailableView("等一段时光", systemImage: "photo.on.rectangle.angled", description: Text(snapshot.emptyMessage))
                                .frame(maxWidth: .infinity).padding(.vertical, 28).glassPanel()
                        } else { hero(model) }
                        if typeSize.isAccessibilitySize {
                            anniversary(model); random(model)
                        } else { HStack(alignment: .top, spacing: 12) { anniversary(model); random(model) } }
                        HStack { Spacer(); Label("待删记录", systemImage: "tray").font(.footnote).foregroundStyle(.secondary).padding(12).glassPanel(); Spacer() }
                            .accessibilityHint("待删复核入口")
                        // F015 supplies the actual count and review navigation. Never fabricate a count.
                    } else if let storageError {
                        Text(storageError).foregroundStyle(.secondary)
                        Button("重试") { Task { await prepare() } }.buttonStyle(.glass)
                    } else { ProgressView("正在读取回顾位置") }
                    Text(snapshot.assets.isEmpty ? snapshot.emptyMessage : "可回顾 \(snapshot.assets.count) 项")
                        .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("home.scope")
                    if snapshot.permission == .limited { Text("仅在你选择的照片范围内回顾").font(.footnote).foregroundStyle(.secondary) }
                }.padding(20).frame(maxWidth: 600)
            }.accessibilityIdentifier("home.scroll")
        }
        .task { await prepare() }
        .onChange(of: snapshot.assets) { _, _ in model?.review.updateLibrary(snapshot) }
        .onChange(of: snapshot.permission) { _, _ in model?.review.updateLibrary(snapshot) }
        .fullScreenCover(isPresented: Binding(get: { model?.presentingReview ?? false }, set: { model?.presentingReview = $0 })) {
            if let model { ReviewEntryView(review: model.review, favorites: model.favorites, pending: model.pending) }
        }
        .alert("回顾提示", isPresented: Binding(get: { model?.message != nil }, set: { if !$0 { model?.message = nil } })) {
            Button("好", role: .cancel) { model?.message = nil }
        } message: { Text(model?.message ?? "") }
    }
    private func prepare() async {
        guard model == nil else { model?.review.updateLibrary(snapshot); return }
        do {
            let paths = try LocalStoragePaths.application()
            let created = HomeModel(store: try LocalStateStore(url: paths.intentStore))
            created.review.updateLibrary(snapshot)
            try await created.review.restore()
            model = created; storageError = nil
        } catch { storageError = "回顾记录暂时无法读取，已有记录会保留。" }
    }
    private func hero(_ model: HomeModel) -> some View {
        Button { Task { await model.resume() } } label: {
            ZStack(alignment: .bottomLeading) {
                HomeArtwork(asset: model.cover(model.heroSegment), cache: model.cache)
                    .frame(height: typeSize.isAccessibilitySize ? 380 : 420)
                LinearGradient(colors: [.black.opacity(typeSize.isAccessibilitySize ? 0.75 : 0), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.heroSegment?.title(calendar: model.timeline.calendar) ?? "一段时光").font(.title2.bold())
                    Text(model.review.state.map { "第\($0.cursor + 1)项 · 共\($0.assetIDs.count)项照片与视频" } ?? "\(model.heroSegment?.assetIDs.count ?? 0)项照片与视频").font(.subheadline)
                    Label(model.review.state == nil ? "开始回顾" : "继续回顾", systemImage: "arrow.right")
                        .font(.headline).padding(.horizontal, 20).padding(.vertical, 14).glassPanel(radius: 30).environment(\.colorScheme, .dark)
                }.foregroundStyle(.white).padding(20)
            }.clipShape(RoundedRectangle(cornerRadius: 28)).contentShape(RoundedRectangle(cornerRadius: 28))
        }.buttonStyle(.plain).accessibilityIdentifier("home.continue")
    }
    private func anniversary(_ model: HomeModel) -> some View {
        Button { Task { await model.open(model.anniversary) } } label: {
            smallCard("去年的今天", subtitle: model.anniversary == nil ? "这一天暂无内容" : "再看这一日", asset: model.cover(model.anniversary), model: model, symbol: "calendar")
        }.buttonStyle(.plain).accessibilityIdentifier("home.anniversary")
    }
    private func random(_ model: HomeModel) -> some View {
        Button { Task { await model.random() } } label: {
            smallCard("随机时光", subtitle: "走进一段连续回忆", asset: model.cover(model.segments.first), model: model, symbol: "shuffle")
        }.buttonStyle(.plain).disabled(snapshot.assets.isEmpty).accessibilityIdentifier("home.random")
    }
    private func smallCard(_ title: String, subtitle: String, asset: PhotoAssetSnapshot?, model: HomeModel, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeArtwork(asset: asset, cache: model.cache, symbol: symbol).frame(height: 120).clipped()
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }.padding(14)
        }.frame(maxWidth: .infinity, alignment: .leading).glassPanel().clipShape(RoundedRectangle(cornerRadius: 24)).contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct HomeArtwork: View {
    let asset: PhotoAssetSnapshot?
    let cache: PhotoMemoryCache
    var symbol = "photo"
    @State private var loader: PhotoLoader?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [.cyan.opacity(0.4), .blue.opacity(0.15), .orange.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let loader, case .ready(let image) = loader.state {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else { Image(systemName: symbol).font(.largeTitle).foregroundStyle(.secondary) }
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
        .task(id: asset) {
            loader?.cancel()
            guard let asset else { return }
            let request = PhotoLoader(cache: cache); loader = request
            request.load(PhotoRequestKey(assetID: asset.id, version: asset.modificationDate, width: 1000, height: 1000), network: false)
        }
        .onDisappear { loader?.cancel() }
    }
}
