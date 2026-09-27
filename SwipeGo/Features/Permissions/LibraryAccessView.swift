import SwiftUI
import PhotosUI

@MainActor @Observable
final class LibraryAccessModel: NSObject, PHPhotoLibraryChangeObserver {
    var snapshot = LibrarySnapshot(permission: .notDetermined, assets: [], sharedLibraryMembershipVerified: false)
    private let gateway = PhotoLibraryGateway()
    private var observing = false
    private var generation = 0
    func refresh() async {
        generation += 1
        let requestGeneration = generation
        let result = await gateway.snapshot()
        guard requestGeneration == generation else { return }
        snapshot = result
        if snapshot.permission.canRead && !observing {
            PHPhotoLibrary.shared().register(self)
            observing = true
        }
    }
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in await self?.refresh() }
    }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    func request() async { _ = await gateway.requestAccess(); await refresh() }
}

struct LibraryAccessView: View {
    @State private var model = LibraryAccessModel()
    @State private var showPicker = false
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if model.snapshot.permission.canRead {
                HomeView(snapshot: model.snapshot) { showSettings = true }
            } else { permissionContent }
        }
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, value in
            if value == .active { Task { await model.refresh() } }
        }
        .sheet(isPresented: $showSettings) {
            VStack { permissionContent; Button("完成") { showSettings = false }.buttonStyle(.glass) }
                .presentationBackground(.regularMaterial)
        }
    }
    private var permissionContent: some View {
        VStack(spacing: 20) {
            Text("时光").font(.largeTitle.bold())
            Text("回顾照片与视频")
            Text(model.snapshot.permission.guidance).multilineTextAlignment(.center)
                .accessibilityIdentifier("permission.guidance")
            if model.snapshot.permission == .notDetermined {
                Button("允许访问照片") { Task { await model.request() } }
                    .buttonStyle(.glassProminent).accessibilityIdentifier("permission.request")
            }
            if model.snapshot.permission == .denied {
                Button("打开设置") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
            }
            if model.snapshot.permission == .limited {
                Button("管理所选照片") { showPicker = true }.buttonStyle(.glass)
            }
            if model.snapshot.permission.canRead {
                Text(model.snapshot.assets.isEmpty ? model.snapshot.emptyMessage : "可回顾 \(model.snapshot.assets.count) 项")
                    .accessibilityIdentifier("library.count")
                Text("共享图库暂不支持；请勿使用共享图库进行测试。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .sheet(isPresented: $showPicker, onDismiss: { Task { await model.refresh() } }) {
            LimitedLibraryPicker { showPicker = false }
        }
    }
}

private struct LimitedLibraryPicker: UIViewControllerRepresentable {
    let finished: @MainActor () -> Void
    func makeUIViewController(context: Context) -> PickerHost {
        let controller = PickerHost(); controller.finished = finished; return controller
    }
    func updateUIViewController(_ controller: PickerHost, context: Context) {}
    final class PickerHost: UIViewController {
        var finished: (@MainActor () -> Void)?
        private var shown = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !shown else { return }; shown = true
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self) { [weak self] _ in
                Task { @MainActor in self?.finished?() }
            }
        }
    }
}
