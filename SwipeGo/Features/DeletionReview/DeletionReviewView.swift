import SwiftUI

struct DeletionReviewView: View {
    @State var model: DeletionReviewModel
    let snapshot: LibrarySnapshot
    var onConfirm: ((FrozenDeletion) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var preview: PhotoAssetSnapshot?
    private var groups: [[DeletionReviewRow]] {
        var ordered: [String] = []; var values: [String: [DeletionReviewRow]] = [:]
        for row in model.rows {
            let key = row.intent.groupID ?? "single:\(row.id)"
            if values[key] == nil { ordered.append(key) }
            values[key, default: []].append(row)
        }
        return ordered.compactMap { values[$0] }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("再看一眼，再决定").font(.largeTitle.bold())
                    Text("待删 \(model.readyCount) 项" + (model.needsReviewCount > 0 ? " · 待核对 \(model.needsReviewCount) 项" : ""))
                        .accessibilityIdentifier("deletion.count")
                    Text("标记还没有删除原片，随时可以撤回。").foregroundStyle(.secondary)
                    if model.isBusy { ProgressView("正在核对") }
                    if let error = model.error { Text(error).foregroundStyle(.red); Button("刷新") { Task { await model.refresh() } } }
                    if model.rows.isEmpty && !model.isBusy && model.error == nil { ContentUnavailableView("没有待删记录", systemImage: "tray") }
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, rows in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(rows.first?.intent.groupID == nil ? "单独标记" : "相似照片 · 第 \(index + 1) 组").font(.headline)
                            ForEach(rows) { row in
                                HStack(alignment: .top, spacing: 12) {
                                    if let asset = row.asset { mediaButton(asset).frame(width: 104, height: 104) }
                                    else { Image(systemName: "photo.badge.exclamationmark").frame(width: 104, height: 104).background(.quaternary) }
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(row.asset?.kind == .video ? "待删视频" : "待删照片").font(.headline)
                                        if row.asset?.isFavorite == true { Label("已收藏，请仔细确认", systemImage: "heart.fill").font(.caption) }
                                        if row.needsReview { Text("需要核对：项目不可访问或保留决定存在冲突。记录仍保留，未确认删除。").font(.caption).foregroundStyle(.orange) }
                                        Button("撤回待删") { Task { await model.retract(row.intent) } }.buttonStyle(.glass).disabled(model.isBusy)
                                            .accessibilityIdentifier("deletion.retract.\(index)")
                                    }
                                }
                            }
                            if let context = rows.first?.intent.comparison {
                                Text("同组已保留 \(context.keptIDs.count) 张").font(.subheadline).accessibilityIdentifier("deletion.keepers")
                                ScrollView(.horizontal) {
                                    HStack { ForEach(rows.first?.keepers ?? []) { asset in mediaButton(asset).frame(width: 120, height: 110) } }
                                }
                                if (rows.first?.keepers.count ?? 0) != context.keptIDs.count { Text("部分保留照片暂不可访问，请先核对。").foregroundStyle(.orange) }
                            }
                        }.padding(16).glassPanel()
                    }
                    Button("复核这 \(model.readyCount) 项") { Task { await model.freeze() } }.buttonStyle(.glassProminent)
                        .disabled(model.isBusy || model.readyCount == 0 || model.needsReviewCount > 0 || model.error != nil)
                        .accessibilityIdentifier("deletion.prepare")
                }.padding(20)
            }.background(RecollectionBackground())
                .navigationTitle("待删复核").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("稍后处理") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("deletion.close") } }
                .task { await model.refresh() }
                .onChange(of: snapshot.assets) { _, _ in Task { await model.refresh() } }
                .onChange(of: snapshot.permission) { _, _ in Task { await model.refresh() } }
                .onChange(of: scenePhase) { _, value in if value == .active { Task { await model.refresh() } } }
                .sheet(item: $model.frozen) { frozen in
                    DeletionConfirmationView(frozen: frozen, onConfirm: onConfirm)
                }
                .fullScreenCover(item: $preview) { asset in
                    if asset.kind == .video { DeletionVideoPreview(asset: asset) }
                    else { ComparisonZoomView(asset: asset, closeTitle: "返回复核") }
                }
        }
    }
    private func mediaButton(_ asset: PhotoAssetSnapshot) -> some View {
        Button { preview = asset } label: {
            if asset.kind == .video {
                ZStack { Color.black; Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.white) }.clipShape(.rect(cornerRadius: 16))
            } else { ComparisonPhoto(asset: asset).clipShape(.rect(cornerRadius: 16)) }
        }.buttonStyle(.plain).accessibilityLabel(asset.kind == .video ? "播放视频确认" : "放大照片确认")
    }
}

struct DeletionConfirmationView: View {
    let frozen: FrozenDeletion
    var onConfirm: ((FrozenDeletion) -> Void)?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("本次共 \(frozen.targets.count) 项").font(.title.bold()).accessibilityIdentifier("deletion.frozen-count")
                    Text("请核对以下固定清单。启用 iCloud 照片时，删除会同步到使用同一图库的设备。")
                    Text("删除后可在系统“最近删除”中尝试恢复，以系统显示的剩余时间为准；不保证永久找回。")
                    Text("仅适用于个人图库；共享照片图库暂不支持。").foregroundStyle(.secondary)
                    ForEach(Array(frozen.targets.enumerated()), id: \.element.id) { index, asset in
                        HStack {
                            if asset.kind == .photo { ComparisonPhoto(asset: asset).frame(width: 90, height: 90).clipShape(.rect(cornerRadius: 12)) }
                            else { Image(systemName: "video").frame(width: 90, height: 90) }
                            VStack(alignment: .leading) {
                                Text("\(index + 1). \(asset.kind == .video ? "视频" : "照片")")
                                Text(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "日期未知").font(.caption)
                                if asset.isFavorite { Text("已收藏").foregroundStyle(.orange) }
                            }
                        }
                    }
                    Button("确认删除这 \(frozen.targets.count) 项", role: .destructive) { onConfirm?(frozen) }
                        .buttonStyle(.glassProminent).disabled(onConfirm == nil).accessibilityIdentifier("deletion.execute")
                    Button("返回复核") { dismiss() }.buttonStyle(.glass).accessibilityIdentifier("deletion.cancel")
                }.padding(20)
            }.navigationTitle("确认清单").navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DeletionVideoPreview: View {
    let asset: PhotoAssetSnapshot
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            VideoReviewView(assetID: asset.id, showControls: true)
            Button("返回复核") { dismiss() }.buttonStyle(.glass).padding().accessibilityIdentifier("deletion.video-close")
        }.background(.black)
    }
}
