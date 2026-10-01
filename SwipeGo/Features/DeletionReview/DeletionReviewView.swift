import SwiftUI

struct DeletionReviewView: View {
    @State var model: DeletionReviewModel
    let snapshot: LibrarySnapshot
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showReconciliation = false
    @State private var preview: PhotoAssetSnapshot?
    @State private var returnHome = false
    @State private var paletteModel = PhotoPaletteModel()
    @State private var confirmationPalette: PhotoPalette = .neutral
    private var paletteAsset: PhotoAssetSnapshot? {
        snapshot.permission.canRead ? model.rows.compactMap(\.asset).first { $0.kind == .photo } : nil
    }
    private var groups: [[DeletionReviewRow]] {
        var ordered: [String] = []; var values: [String: [DeletionReviewRow]] = [:]
        for row in model.rows {
            let key = row.intent.groupID.map { "group:\($0)" } ?? "single"
            if values[key] == nil { ordered.append(key) }
            values[key, default: []].append(row)
        }
        return ordered.compactMap { values[$0] }
    }
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 240 : 100), spacing: 12)] }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("再看一眼，再决定").font(.title.bold())
                    Text("待删 \(model.readyCount) 项" + (model.needsReviewCount > 0 ? " · 待核对 \(model.needsReviewCount) 项" : ""))
                        .accessibilityIdentifier("deletion.count")
                    Text("点照片查看，点减号撤回标记。").font(.subheadline).foregroundStyle(PhotoTheme.secondary)
                    if model.unresolvedCount > 0 {
                        Button("有未完成操作 · 点此核对") { showReconciliation = true }
                            .buttonStyle(PhotoGlassButtonStyle()).accessibilityIdentifier("deletion.reconcile")
                    }
                    if model.isBusy { ProgressView("正在核对").padding(20).frame(maxWidth: .infinity).photoGlass() }
                    if let error = model.error { PhotoStatusCard(title: "需要重新核对", message: error, color: PhotoTheme.warning); Button("刷新") { Task { await model.refresh() } }.buttonStyle(PhotoGlassButtonStyle()) }
                    if model.rows.isEmpty && !model.isBusy && model.error == nil { PhotoStatusCard(title: "没有待删记录", message: "照片仍在图库中，继续回顾你的时光。", icon: "tray") }
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, rows in
                        VStack(alignment: .leading, spacing: 12) {
                            if rows.first?.intent.groupID != nil { Text("相似照片 · 第 \(index + 1) 组").font(.headline) }
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(rows) { row in
                                    VStack(alignment: .leading, spacing: 6) {
                                        ZStack(alignment: .topTrailing) {
                                            if let asset = row.asset { mediaButton(asset).frame(height: 130) }
                                            else { Image(systemName: "photo.badge.exclamationmark").frame(maxWidth: .infinity).frame(height: 130).photoGlass(radius: 16).clipShape(.rect(cornerRadius: 16)) }
                                            Button { Task { await model.retract(row.intent) } } label: {
                                                Image(systemName: "minus").frame(width: 44, height: 44).contentShape(Rectangle()).recollectionGlass(radius: 24)
                                            }.buttonStyle(.plain).disabled(model.isBusy).accessibilityLabel("撤回待删")
                                                .accessibilityIdentifier("deletion.retract.\(model.rows.firstIndex(where: { $0.id == row.id }) ?? 0)")
                                        }
                                        if row.asset?.isFavorite == true { Label("已收藏", systemImage: "heart.fill").font(.caption).foregroundStyle(PhotoTheme.warning) }
                                        if row.needsReview { Text("需要核对，未确认删除").font(.caption).foregroundStyle(PhotoTheme.warning) }
                                        else { Text(row.asset?.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "日期未知").font(.caption).foregroundStyle(PhotoTheme.secondary) }
                                    }
                                }
                            }
                            if let context = rows.first?.intent.comparison {
                                Text("同组已保留 \(context.keptIDs.count) 张").font(.subheadline).accessibilityIdentifier("deletion.keepers")
                                ScrollView(.horizontal) { HStack { ForEach(rows.first?.keepers ?? []) { asset in mediaButton(asset).frame(width: 100, height: 90) } } }
                                if (rows.first?.keepers.count ?? 0) != context.keptIDs.count { Text("部分保留照片暂不可访问，请先核对。").foregroundStyle(PhotoTheme.warning) }
                            }
                        }
                    }
                    DeletionExplanation()
                }.padding(20)
            }.clipped().accessibilityIdentifier("deletion.review-scroll")
                Button("复核这 \(model.readyCount) 项") {
                    confirmationPalette = paletteModel.freeze()
                    Task {
                        await model.freeze()
                        if model.frozen == nil { paletteModel.reset(); paletteModel.load(paletteAsset) }
                    }
                }
                    .buttonStyle(PhotoGlassButtonStyle()).padding(.horizontal, 20).padding(.vertical, 10)
                    .disabled(model.isBusy || model.readyCount == 0 || model.needsReviewCount > 0 || model.error != nil)
                    .accessibilityIdentifier("deletion.prepare")
            }
            .background(PhotoPaletteBackground(palette: paletteModel.palette)).photoPage()
            .toolbarBackground(.hidden, for: .navigationBar)
            .task(id: paletteAsset) { if model.frozen == nil { paletteModel.load(paletteAsset) } }
            .onDisappear { paletteModel.cancel() }
            .navigationTitle("待删复核").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("稍后处理") { dismiss() }.buttonStyle(.glass).disabled(model.isBusy).accessibilityIdentifier("deletion.close") } }
            .task { await model.refresh() }
            .onChange(of: snapshot.assets) { _, _ in Task { await model.refresh() } }
            .onChange(of: snapshot.permission) { _, _ in Task { await model.refresh() } }
            .onChange(of: scenePhase) { _, value in if value == .active { Task { await model.refresh() } } }
            .sheet(isPresented: $showReconciliation, onDismiss: { Task { await model.refresh() } }) { ReconciliationView(model: ReconciliationCoordinator(store: model.store), palette: paletteModel.palette) }
            .sheet(item: $model.frozen, onDismiss: {
                Task { await model.refresh(); paletteModel.reset(); paletteModel.load(paletteAsset) }
                if returnHome { returnHome = false; dismiss() }
            }) { frozen in
                DeletionConfirmationView(frozen: frozen, palette: confirmationPalette, coordinator: model.deletion, store: model.store,
                                         didAttempt: { await model.refreshAfterAttempt() }) { home in
                    returnHome = home; model.frozen = nil
                }
            }
            .fullScreenCover(item: $preview) { asset in
                if asset.kind == .video { DeletionVideoPreview(asset: asset) }
                else { ComparisonZoomView(asset: asset, closeTitle: "返回复核") }
            }
        }
    }
    private func mediaButton(_ asset: PhotoAssetSnapshot) -> some View {
        Button { preview = asset } label: { DeletionThumbnail(asset: asset) }
            .buttonStyle(.plain).accessibilityLabel(asset.kind == .video ? "播放视频确认" : "放大照片确认")
    }
}

struct DeletionConfirmationView: View {
    let frozen: FrozenDeletion
    var palette: PhotoPalette = .neutral
    let coordinator: DeletionCoordinator
    let store: any LocalStateRepository
    var didAttempt: () async -> Void
    var finished: (Bool) -> Void
    @State private var personalLibrary = false
    @State private var result: DeletionResult?
    @State private var attempted = false
    @State private var showHistory = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    if let result { resultContent(result) }
                    else {
                        Text("本次共 \(frozen.targets.count) 项").font(.title.bold()).accessibilityIdentifier("deletion.frozen-count")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 240 : 100), spacing: 12)], spacing: 12) {
                            ForEach(frozen.targets) { asset in
                                VStack(alignment: .leading, spacing: 6) {
                                    DeletionThumbnail(asset: asset).frame(height: 120)
                                    Text(asset.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "日期未知").font(.caption)
                                    if asset.isFavorite { Label("已收藏", systemImage: "heart.fill").font(.caption).foregroundStyle(PhotoTheme.warning) }
                                }
                            }
                        }
                        DeletionExplanation()
                        Text("删除会同步到同一 iCloud 图库；恢复以系统“最近删除”的保留期为准。").font(.footnote).foregroundStyle(PhotoTheme.secondary)
                        Toggle("我使用个人图库，未加入共享照片图库", isOn: $personalLibrary)
                            .disabled(coordinator.isBusy || attempted).accessibilityIdentifier("deletion.personal-library")
                        if coordinator.isBusy { ProgressView("等待系统删除结果") }
                    }
                }.padding(20)
            }.clipped().accessibilityIdentifier("deletion.confirm-scroll")
                VStack(spacing: 12) {
                    if result == nil {
                        Button("确认删除这 \(frozen.targets.count) 项", role: .destructive) { Task { await execute() } }
                            .buttonStyle(PhotoGlassButtonStyle(destructive: true))
                            .disabled(!personalLibrary || coordinator.isBusy || attempted).accessibilityIdentifier("deletion.execute")
                    }
                    Button(result?.outcome == .succeeded ? "返回回顾" : "返回复核") { finished(result?.outcome == .succeeded) }
                        .buttonStyle(PhotoGlassButtonStyle()).disabled(coordinator.isBusy).accessibilityIdentifier("deletion.cancel")
                }.padding(.horizontal, 20).padding(.vertical, 12)
            }
            .background(PhotoPaletteBackground(palette: palette)).photoPage()
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle(result == nil ? "确认清单" : "删除结果").navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(coordinator.isBusy)
            .sheet(isPresented: $showHistory) { DeletionHistoryView(store: store, palette: palette).presentationBackground(.clear) }
        }
    }
    private func resultContent(_ result: DeletionResult) -> some View {
        VStack(spacing: 24) {
            DeletionResultCard(result: result)
            Button("查看删除记录", systemImage: "clock.arrow.circlepath") { showHistory = true }
                .buttonStyle(PhotoGlassButtonStyle()).accessibilityIdentifier("deletion.history")
        }.frame(maxWidth: .infinity).padding(.vertical, 20)
    }
    private func execute() async {
        guard !attempted else { return }; attempted = true
        do {
            let receipt = try await coordinator.execute(frozen)
            result = DeletionResult(receipt, count: frozen.targets.count, remaining: try? await store.pending().count)
        } catch { result = DeletionResult(.failed, count: frozen.targets.count) }
        await didAttempt()
    }
}

private struct DeletionThumbnail: View {
    let asset: PhotoAssetSnapshot
    var body: some View {
        Group {
            if asset.kind == .video { ZStack { Color.black; Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.white) } }
            else { ComparisonPhoto(asset: asset) }
        }.frame(maxWidth: .infinity).clipShape(.rect(cornerRadius: 16))
    }
}

/// First use expands the explanation; subsequent visits keep a small glass entry.
private struct DeletionExplanation: View {
    @AppStorage("deletionExplanationSeen.v1") private var seen = false
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { if expanded { seen = true }; expanded.toggle() } label: {
                HStack { Label("删除说明", systemImage: "info.circle"); Spacer(); Image(systemName: expanded ? "chevron.up" : "chevron.down") }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("deletion.info")
            if expanded {
                Text("标记不会删除原片，可以随时撤回。确认后仍需在系统提示中决定是否删除。")
                Text("启用 iCloud 照片时，删除会同步到同一图库的设备。可在系统“最近删除”中尝试恢复，以系统显示的剩余时间为准，不保证永久找回。")
                Text("仅适用于个人图库；共享照片图库暂不支持。")
                Button("知道了") { seen = true; expanded = false }.frame(minHeight: 44).accessibilityIdentifier("deletion.info.acknowledge")
            }
        }.font(.subheadline).padding(.horizontal, 16).padding(.vertical, 6)
            .photoGlass().onAppear { expanded = !seen }
    }
}

private struct DeletionVideoPreview: View {
    let asset: PhotoAssetSnapshot
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            VideoReviewView(assetID: asset.id, showControls: true)
            Button("返回复核") { dismiss() }.buttonStyle(.plain).frame(minHeight: 44).padding(.horizontal, 24).recollectionGlass().padding().accessibilityIdentifier("deletion.video-close")
        }.background(.black)
    }
}
