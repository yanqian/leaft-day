#if DEBUG
import SwiftUI
import Photos
import Synchronization

struct DeletionTestHost: View {
    @State private var model: DeletionReviewModel?
    @State private var snapshot: LibrarySnapshot?
    @State private var status = "准备删除测试"
    @State private var targetIDs: [String] = []
    @State private var keeperID: String?
    var body: some View {
        VStack {
            if let model, let snapshot {
                DeletionReviewView(model: model, snapshot: snapshot)
                Button("检查测试结果") { Task { await inspect(model.store) } }.accessibilityIdentifier("deletion.test-check")
            }
            Text(status).font(.caption).accessibilityIdentifier("deletion.test-state")
        }.task {
            #if targetEnvironment(simulator)
            do {
                let gateway = PhotoLibraryGateway()
                if await !gateway.snapshot().permission.canRead { _ = await gateway.requestAccess() }
                let images = [UIColor.red, .green, .blue].map { color in
                    UIGraphicsImageRenderer(size: CGSize(width: 240, height: 180)).image { context in
                        color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 240, height: 180))
                    }
                }
                let ids = Mutex<[String]>([])
                try await PHPhotoLibrary.shared().performChanges { @Sendable in
                    for image in images {
                        if let id = PHAssetChangeRequest.creationRequestForAsset(from: image).placeholderForCreatedAsset?.localIdentifier { ids.withLock { $0.append(id) } }
                    }
                }
                let created = ids.withLock { $0 }
                guard created.count == 3 else { status = "创建测试素材失败"; return }
                targetIDs = Array(created.prefix(2)); keeperID = created[2]
                let store = try LocalStateStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".store"))
                for (offset, id) in targetIDs.enumerated() {
                    try await store.markPending(PendingIntent(assetID: id, groupID: "disposable", markedAt: .distantPast.addingTimeInterval(Double(offset)), comparison: ComparisonContext(assetIDs: created, keptIDs: [created[2]])))
                }
                snapshot = await gateway.snapshot(); model = DeletionReviewModel(store: store)
                await inspect(store)
            } catch { status = "测试准备失败：\(error)" }
            #else
            status = "仅模拟器创建可丢弃素材，真机禁止此入口"
            #endif
        }
    }
    private func inspect(_ store: any LocalStateRepository) async {
        let visible = PHAsset.fetchAssets(withLocalIdentifiers: targetIDs, options: nil).count
        let kept = keeperID.map { PHAsset.fetchAssets(withLocalIdentifiers: [$0], options: nil).count } ?? 0
        let pending = (try? await store.pending().count) ?? -1
        let operations = (try? await store.operations()) ?? []
        status = "targets=\(visible) keeper=\(kept) pending=\(pending) success=\(operations.filter { $0.phase == .succeeded }.count) cancelled=\(operations.filter { $0.deletionOutcome == .cancelled }.count)"
    }
}
#endif
