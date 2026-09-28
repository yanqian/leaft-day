#if DEBUG
import SwiftUI
import Photos

struct ComparisonTestHost: View {
    @State private var assets: [PhotoAssetSnapshot] = []
    @State private var pending: PendingCoordinator?
    @State private var shown = false
    @State private var failure: String?
    var body: some View {
        VStack {
            Text(failure ?? "pending=\(pending?.items.count ?? 0)").accessibilityIdentifier("comparison.test-state")
            Button("打开比较") { shown = true }.disabled(pending == nil)
        }.sheet(isPresented: $shown) {
            if let pending { ComparisonView(groups: [SimilarityGroup(assetIDs: assets.map(\.id))], assets: assets, pending: pending) }
        }.task {
            #if targetEnvironment(simulator)
            do {
                let gateway = PhotoLibraryGateway()
                if await !gateway.snapshot().permission.canRead { _ = await gateway.requestAccess() }
                let snapshot = await gateway.snapshot()
                var ids: [String: String] = [:]
                PHAsset.fetchAssets(withLocalIdentifiers: snapshot.assets.map(\.id), options: nil).enumerateObjects { asset, _, _ in
                    for resource in PHAssetResource.assetResources(for: asset) { ids[resource.originalFilename] = asset.localIdentifier }
                }
                assets = ["landscape.jpg", "landscape-copy.jpg", "landscape-near.jpg"].compactMap { name in snapshot.assets.first { $0.id == ids[name] } }
                guard assets.count == 3 else { failure = "需要三张生成素材"; return }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".store")
                pending = PendingCoordinator(store: try LocalStateStore(url: url))
                shown = true
            } catch { failure = String(describing: error) }
            #else
            failure = "此测试入口仅用于模拟器生成素材"
            #endif
        }
    }
}
#endif
