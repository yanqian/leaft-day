import SwiftUI
import PhotosUI

@MainActor @Observable
final class LibraryAccessModel: NSObject, PHPhotoLibraryChangeObserver {
    var snapshot = LibrarySnapshot(permission: .notDetermined, assets: [], sharedLibraryMembershipVerified: false)
    private(set) var loading = true
    private(set) var requesting = false
    private let gateway = PhotoLibraryGateway()
    private var observing = false
    private var generation = 0
    func refresh() async {
        // A native permission prompt owns this transition. Avoid overlapping
        // foreground snapshots while PhotoKit is still resolving its request.
        guard !requesting else { return }
        generation += 1
        let requestGeneration = generation
        let result = await gateway.snapshot()
        guard requestGeneration == generation else { return }
        snapshot = result
        loading = false
        if snapshot.permission.canRead && !observing {
            PHPhotoLibrary.shared().register(self)
            observing = true
        }
    }
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in await self?.refresh() }
    }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    func request() async {
        guard !requesting else { return }
        requesting = true
        _ = await gateway.requestAccess()
        requesting = false
        await refresh()
    }
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
            LibrarySettingsView(snapshot: model.snapshot, request: { Task { await model.request() } },
                                manage: { showPicker = true }, openSettings: { openURL(URL(string: UIApplication.openSettingsURLString)!) },
                                done: { showSettings = false })
                .presentationBackground(.clear)
                .sheet(isPresented: $showPicker, onDismiss: { Task { await model.refresh() } }) {
                    LimitedLibraryPicker { showPicker = false }
                }
        }
    }
    private var permissionContent: some View {
        PhotoAccessWelcomeView(permission: model.snapshot.permission, loading: model.loading, requesting: model.requesting,
            request: { Task { await model.request() } },
            openSettings: { openURL(URL(string: UIApplication.openSettingsURLString)!) },
            retry: { Task { await model.refresh() } })
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
