import SwiftUI

struct ComparisonView: View {
    let groups: [SimilarityGroup]
    let assets: [PhotoAssetSnapshot]
    let pending: PendingCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var keeping = Set<String>()
    @State private var zoomed: PhotoAssetSnapshot?
    @State private var error: String?
    @State private var saved = false
    private var group: [PhotoAssetSnapshot] {
        guard groups.indices.contains(index) else { return [] }
        return groups[index].assetIDs.compactMap { id in assets.first { $0.id == id } }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("留下值得再看的").font(.largeTitle.bold())
                    Text("选中的照片会保留。相似不代表多余，请逐张确认。").foregroundStyle(.secondary)
                    if group.count >= 2 {
                        Text("第 \(index + 1) / \(groups.count) 组 · 保留 \(keeping.count) 张").font(.subheadline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                            ForEach(group) { asset in
                                VStack(spacing: 8) {
                                    Button { zoomed = asset } label: { ComparisonPhoto(asset: asset).frame(height: 170).clipShape(.rect(cornerRadius: 18)) }
                                        .buttonStyle(.plain).accessibilityLabel("放大照片 \(position(asset))")
                                        .accessibilityIdentifier("comparison.zoom.\(position(asset))")
                                    Button {
                                        if keeping.contains(asset.id) { keeping.remove(asset.id) } else { keeping.insert(asset.id) }
                                        saved = false; error = nil
                                    } label: {
                                        Label(asset.isFavorite ? "已收藏 · 保留" : keeping.contains(asset.id) ? "保留" : "加入待删", systemImage: keeping.contains(asset.id) ? "checkmark.circle.fill" : "circle")
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }.buttonStyle(.glass).disabled(asset.isFavorite || pending.isBusy)
                                        .accessibilityIdentifier("comparison.keep.\(position(asset))")
                                }
                            }
                        }
                        if keeping.isEmpty { Text("请至少保留一张照片。").foregroundStyle(.orange).accessibilityIdentifier("comparison.empty") }
                        if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("comparison.error") }
                        if saved { Text("已保存待删选择，原片未删除。").accessibilityIdentifier("comparison.saved") }
                        Button("确认：保留 \(keeping.count) 张，待删 \(group.count - keeping.count) 张") { save(keeping) }
                            .buttonStyle(.glassProminent).disabled(keeping.isEmpty || pending.isBusy || saved)
                            .accessibilityIdentifier("comparison.confirm")
                        HStack {
                            Button("全部保留") { save(Set(group.map(\.id))) }.disabled(pending.isBusy)
                                .accessibilityIdentifier("comparison.keep-all")
                            Spacer()
                            Button(saved ? "下一组" : "以后再看") { advance() }.disabled(pending.isBusy)
                                .accessibilityIdentifier("comparison.skip")
                        }.buttonStyle(.glass)
                    } else { ContentUnavailableView("这一组暂时不可用", systemImage: "photo", description: Text("返回回顾后重新分析。")) }
                }.padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("相似时光").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.disabled(pending.isBusy).accessibilityIdentifier("comparison.close") } }
            .task(id: index) { keeping = Set(group.map(\.id)); saved = false; error = nil }
            .fullScreenCover(item: $zoomed) { asset in ComparisonZoomView(asset: asset) }
            .interactiveDismissDisabled(pending.isBusy)
        }
    }
    private func position(_ asset: PhotoAssetSnapshot) -> Int { (group.firstIndex(where: { $0.id == asset.id }) ?? 0) + 1 }
    private func save(_ selection: Set<String>) {
        let frozen = group
        Task {
            do { _ = try await pending.compare(frozen, keeping: selection); keeping = selection; saved = true; error = nil }
            catch { self.error = "未能保存，照片状态可能已变化。请返回回顾重新比较。" }
        }
    }
    private func advance() {
        if index + 1 < groups.count { index += 1 } else { dismiss() }
    }
}

struct ComparisonPhoto: View {
    let asset: PhotoAssetSnapshot
    var pixels = 600
    @State private var loader = PhotoLoader(cache: PhotoMemoryCache(byteLimit: 16 * 1024 * 1024, countLimit: 1))
    var body: some View {
        ZStack {
            Color.black
            switch loader.state {
            case .ready(let image): PhotoContentView(image: image)
            case .idle, .loading: ProgressView().tint(.white)
            default: Text("照片暂不可用").foregroundStyle(.white)
            }
        }.task(id: asset.id) { loader.load(PhotoRequestKey(assetID: asset.id, version: asset.modificationDate, width: pixels, height: pixels)) }
            .onDisappear { loader.releaseMemory() }
    }
}

struct ComparisonZoomView: View {
    let asset: PhotoAssetSnapshot
    var closeTitle = "返回比较"
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var base: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var origin = CGSize.zero
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            ComparisonPhoto(asset: asset, pixels: 2048).scaleEffect(scale).offset(offset)
                .gesture(MagnifyGesture().onChanged { scale = min(4, max(1, base * $0.magnification)) }.onEnded { _ in base = scale })
                .simultaneousGesture(DragGesture().onChanged { if scale > 1 { offset = CGSize(width: origin.width + $0.translation.width, height: origin.height + $0.translation.height) } }.onEnded { _ in origin = offset })
            HStack {
                Button(scale == 1 ? "放大" : "还原") { scale = scale == 1 ? 2 : 1; base = scale; offset = .zero; origin = .zero }
                    .accessibilityIdentifier("comparison.zoom-toggle")
                Button(closeTitle) { dismiss() }.accessibilityIdentifier("comparison.zoom-close")
            }.buttonStyle(.glass).padding(16).glassPanel().padding(20)
        }.clipped().statusBarHidden(true)
    }
}
