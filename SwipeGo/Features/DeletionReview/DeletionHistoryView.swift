import SwiftUI

struct DeletionHistoryView: View {
    private let palette: PhotoPalette
    private let read: @MainActor () async throws -> [OperationState]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var operations: [OperationState] = []
    @State private var loading = true
    @State private var error: String?
    init(store: any LocalStateRepository, palette: PhotoPalette = .neutral) { self.palette = palette; read = { try await store.operations() } }
    #if DEBUG
    init(read: @escaping @MainActor () async throws -> [OperationState], palette: PhotoPalette = .neutral) { self.palette = palette; self.read = read }
    #endif
    var body: some View {
        ZStack {
            PhotoPaletteBackground(palette: palette)
            VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("删除记录").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                            Text("最近的操作").font(.subheadline)
                        }
                        Spacer(minLength: 12)
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44).contentShape(Circle())
                        }.buttonStyle(.plain).photoGlass(radius: 24).accessibilityLabel("关闭删除记录")
                    }.padding(.bottom, 12)
                    if loading { ProgressView("正在读取记录").frame(maxWidth: .infinity).padding(24) }
                    else if let error {
                        VStack(spacing: 16) {
                            Label(error, systemImage: "exclamationmark.circle").fixedSize(horizontal: false, vertical: true)
                            Button { Task { await reload() } } label: {
                                Text("重试").frame(maxWidth: .infinity, minHeight: 48).contentShape(Capsule())
                            }.buttonStyle(.plain).photoGlass().accessibilityIdentifier("history.retry")
                        }.padding(20).photoGlass()
                    } else if operations.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "clock.arrow.circlepath").font(.largeTitle)
                            Text("没有删除记录").font(.headline)
                        }.frame(maxWidth: .infinity).padding(28).photoGlass()
                    } else {
                        ForEach(operations, id: \.id) { operation in
                            HStack(alignment: .top, spacing: 14) {
                                if !typeSize.isAccessibilitySize {
                                    Image(systemName: icon(operation)).font(.title2)
                                        .foregroundStyle(operation.deletionOutcome == .success ? PhotoTheme.success : PhotoTheme.warning)
                                        .frame(width: 36, height: 36).accessibilityHidden(true)
                                }
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("\(operation.targetIDs.count) 项 · \(label(operation))")
                                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                                    Text(operation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(20).photoGlass()
                        }
                    }
                }.padding(24).frame(maxWidth: 600)
            }.clipped().accessibilityIdentifier("history.scroll")
                Button { dismiss() } label: {
                    Text("完成").font(.headline).frame(maxWidth: .infinity, minHeight: 52).contentShape(Capsule())
                }.buttonStyle(.plain).photoGlass(radius: 30)
                    .accessibilityIdentifier("deletion.history.close")
                    .padding(.horizontal, 24).padding(.vertical, 14).frame(maxWidth: 600)
            }
        }.photoPage()
            .task { await reload() }
    }
    private func reload() async {
        guard loading || error != nil else { return }
        loading = true; error = nil
        do {
            operations = Array(try await read().filter { $0.kind == .deletion }.sorted { $0.updatedAt > $1.updatedAt }.prefix(20))
        } catch { self.error = "记录暂不可读，请稍后重试。" }
        loading = false
    }
    private func label(_ value: OperationState) -> String {
        switch value.deletionOutcome {
        case .success: "系统已确认删除"
        case .cancelled: "已取消"
        case .notSubmitted: "未提交删除"
        default: "结果待核对"
        }
    }
    private func icon(_ value: OperationState) -> String {
        switch value.deletionOutcome {
        case .success: "checkmark.circle"
        case .cancelled: "xmark.circle"
        case .notSubmitted: "minus.circle"
        default: "questionmark.circle"
        }
    }
}
