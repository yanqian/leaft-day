#if DEBUG
import SwiftUI
import Photos

struct DeletionReviewTestHost: View {
    var interrupted = false
    @State private var snapshot: LibrarySnapshot?
    @State private var store: LocalStateStore?
    @State private var failure: String?
    var body: some View {
        Group {
            if let snapshot, let store { HomeView(snapshot: snapshot, settings: {}, storeOverride: store) }
            else { Text(failure ?? "准备复核测试") }
        }.task {
            #if targetEnvironment(simulator)
            do {
                let gateway = PhotoLibraryGateway()
                if await !gateway.snapshot().permission.canRead { _ = await gateway.requestAccess() }
                let library = await gateway.snapshot()
                var names: [String: String] = [:]
                PHAsset.fetchAssets(withLocalIdentifiers: library.assets.map(\.id), options: nil).enumerateObjects { asset, _, _ in
                    for resource in PHAssetResource.assetResources(for: asset) { names[resource.originalFilename] = asset.localIdentifier }
                }
                guard let photo = names["landscape-near.jpg"], let keeper = names["landscape-copy.jpg"], let video = names["clip.mp4"] else { failure = "缺少生成测试素材"; return }
                let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--reconciliation-store=") })?.split(separator: "=").last.map(String.init)
                let storeID = argument.flatMap(UUID.init(uuidString:)) ?? UUID()
                let local = try LocalStateStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(storeID.uuidString + ".store"))
                let existing = try await local.operations()
                if existing.isEmpty {
                try await local.markPending(PendingIntent(assetID: photo, groupID: "fixture", markedAt: .distantPast, comparison: ComparisonContext(assetIDs: [photo, keeper], keptIDs: [keeper])))
                try await local.markPending(PendingIntent(assetID: video, groupID: nil, markedAt: .distantPast.addingTimeInterval(1)))
                try await local.markPending(PendingIntent(assetID: "unavailable-fixture", groupID: nil, markedAt: .distantPast.addingTimeInterval(2)))
                    if interrupted {
                        try await local.saveOperation(OperationState(id: UUID(), kind: .deletion, targetIDs: [photo], phase: .submitted, updatedAt: .distantPast))
                    }
                }
                store = local; snapshot = library
            } catch { failure = String(describing: error) }
            #else
            failure = "此测试入口仅用于模拟器生成素材"
            #endif
        }
    }
}
#endif
