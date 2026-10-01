import SwiftUI

struct ReconciliationView: View {
    @State var model: ReconciliationCoordinator
    var palette: PhotoPalette = .neutral
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("再核对一下").font(.largeTitle.bold())
                    Label("这些操作没有完整的本地完成记录。照片不可见也可能是授权或图库变化，不能据此认定删除成功。不会自动重试。", systemImage: "questionmark.circle")
                        .fixedSize(horizontal: false, vertical: true).foregroundStyle(PhotoTheme.warning).padding(20).photoGlass()
                    if let error = model.error { PhotoStatusCard(title: "暂时无法读取", message: error, color: PhotoTheme.warning) }
                    if model.isBusy { ProgressView("读取当前事实").frame(maxWidth: .infinity).padding(20).photoGlass() }
                    ForEach(model.records) { record in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(record.operation.kind == .deletion ? "删除结果待核对" : "收藏结果待核对").font(.headline)
                            Text("本次 \(record.operation.targetIDs.count) 项 · 当前可访问 \(record.visible.count) 项")
                            ScrollView(.horizontal) {
                                HStack { ForEach(record.visible) { asset in
                                    VStack {
                                        if asset.kind == .photo { ComparisonPhoto(asset: asset).frame(width: 110, height: 110) }
                                        else { Image(systemName: "video").frame(width: 110, height: 110) }
                                        Text(asset.isFavorite ? "系统当前：已收藏" : "系统当前：未收藏").font(.caption)
                                    }
                                } }
                            }
                            Text("请对照系统照片核对。结束提示只表示你已看过这条记录，不代表操作成功；待删意图仍保留，如需删除必须重新复核。")
                                .font(.footnote).foregroundStyle(PhotoTheme.secondary)
                            Button("已核对，结束此提示") { Task { await model.acknowledge(record) } }
                                .buttonStyle(PhotoGlassButtonStyle()).disabled(model.isBusy).accessibilityIdentifier("reconciliation.acknowledge")
                        }.padding(16).photoGlass()
                    }
                    if model.records.isEmpty && !model.isBusy && model.error == nil { Text("没有需要核对的操作").font(.headline).frame(maxWidth: .infinity).padding(24).photoGlass().accessibilityIdentifier("reconciliation.empty") }
                    Button("刷新当前事实") { Task { await model.refresh() } }.buttonStyle(PhotoGlassButtonStyle()).disabled(model.isBusy)
                }.padding(20)
            }.clipped().accessibilityIdentifier("reconciliation.scroll").background(PhotoPaletteBackground(palette: palette)).photoPage()
                .toolbarBackground(.hidden, for: .navigationBar).navigationTitle("操作核对").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.accessibilityIdentifier("reconciliation.close") } }
                .task { await model.refresh() }
                .onChange(of: scenePhase) { _, value in if value == .active { Task { await model.refresh() } } }
        }
    }
}
