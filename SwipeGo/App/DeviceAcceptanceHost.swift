#if DEBUG
import SwiftUI
import Photos
import Synchronization

@MainActor @Observable final class DeviceAcceptanceModel: NSObject, PHPhotoLibraryChangeObserver {
    struct Manifest: Codable { let runID: UUID; let assetIDs: [String]; let createdAt: Date }
    let runID: UUID
    private let directory: URL
    private var manifest: Manifest?
    var assetIDs: Set<String> { Set(manifest?.assetIDs ?? []) }
    var snapshot: LibrarySnapshot?
    var store: LocalStateStore?
    var message = "此入口只创建和使用本次生成的测试素材，不从个人图库选取内容。"
    var busy = false
    private var generation = 0
    private var observing = false
    init(runID: UUID) {
        self.runID = runID
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeviceAcceptance/" + runID.uuidString)
        super.init()
    }
    func restore() async {
        let url = directory.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let saved = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
            guard saved.runID == runID, saved.assetIDs.count == 4, Set(saved.assetIDs).count == 4 else { throw DeletionError.changed }
            manifest = saved; try openStore(); await refresh()
        } catch { message = "测试清单读取失败，停止测试，不扫描或替换为其他照片。" }
    }
    private func openStore() throws {
        store = try LocalStateStore(url: directory.appendingPathComponent("Intent.store"))
    }
    func create() async {
        guard !busy, manifest == nil else { return }
        busy = true; defer { busy = false }
        do {
            let permission = PhotoLibraryGateway.permission(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
            guard permission.canRead else { message = "需要照片权限才能创建并读取测试素材。"; return }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let names = ["landscape", "landscape-copy", "landscape-near", "clip"]
            let urls = try names.enumerated().map { index, name in
                guard let url = Bundle.main.url(forResource: name, withExtension: index == 3 ? "mp4" : "jpg") else { throw CocoaError(.fileNoSuchFile) }
                return url
            }
            let identifiers = Mutex<[String]>([])
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                for (index, url) in urls.enumerated() {
                    let request = PHAssetCreationRequest.forAsset()
                    request.creationDate = Date(timeIntervalSince1970: 1758938400 + Double(index * 2))
                    request.addResource(with: index == 3 ? .video : .photo, fileURL: url, options: nil)
                    if let id = request.placeholderForCreatedAsset?.localIdentifier { identifiers.withLock { $0.append(id) } }
                }
            }
            let ids = identifiers.withLock { $0 }
            guard ids.count == 4 else { throw DeletionError.changed }
            let saved = Manifest(runID: runID, assetIDs: ids, createdAt: .now)
            try JSONEncoder().encode(saved).write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
            manifest = saved; try openStore(); await refresh()
        } catch { message = "测试素材准备失败：\(error)。停止测试，不使用个人照片代替。" }
    }
    func refresh() async {
        guard let manifest, let store else { return }
        generation += 1; let token = generation
        let reader = NativeFavoriteWriter(); let scope = await reader.accessScope()
        var assets: [PhotoAssetSnapshot] = []
        for id in manifest.assetIDs { if let asset = try? await reader.asset(id: id) { assets.append(asset) } }
        guard token == generation else { return }
        do {
            let pending = try await store.pending()
            guard Set(pending.map(\.assetID)).isSubset(of: Set(manifest.assetIDs)) else { snapshot = nil; message = "本地测试意图越出生成清单，已停止。"; return }
            snapshot = LibrarySnapshot(permission: scope.permission, assets: assets, sharedLibraryMembershipVerified: false)
            message = "测试清单4项 · 当前可见\(assets.count)项 · 收藏\(assets.filter(\.isFavorite).count)项 · 待删\(pending.count)项"
        } catch { snapshot = nil; message = "测试记录读取失败，已停止。" }
        if !observing { PHPhotoLibrary.shared().register(self); observing = true }
    }
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) { Task { @MainActor [weak self] in await self?.refresh() } }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
}

struct DeviceAcceptanceHost: View {
    @State private var model: DeviceAcceptanceModel
    @Environment(\.scenePhase) private var scenePhase
    init(runID: UUID) { _model = State(initialValue: DeviceAcceptanceModel(runID: runID)) }
    var body: some View {
        VStack(spacing: 4) {
            if let snapshot = model.snapshot, let store = model.store {
                HomeView(snapshot: snapshot, settings: {}, storeOverride: store, assetScope: model.assetIDs)
                Button("刷新测试清单") { Task { await model.refresh() } }.accessibilityIdentifier("device.refresh")
            } else {
                Text("真机验收 · 可丢弃素材").font(.title)
                Button("创建本次4项测试素材") { Task { await model.create() } }.buttonStyle(.glassProminent)
                    .disabled(model.busy).accessibilityIdentifier("device.create")
            }
            Text(model.message).font(.caption).accessibilityIdentifier("device.state")
        }.task { await model.restore() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refresh() } } }
    }
}
#endif
