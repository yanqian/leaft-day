#if DEBUG
import SwiftUI
import Photos

/// Uses the actual HomeView -> fullScreenCover -> ReviewEntryView presentation.
/// Only local fixture IDs are admitted, and its store is separate from user intent.
struct HomeNavigationTestHost: View {
    var continuity = false
    @State private var snapshot: LibrarySnapshot?
    @State private var store: LocalStateStore?
    @State private var error: String?
    var body: some View {
        Group {
            if let snapshot, let store {
                HomeView(snapshot: snapshot, settings: {}, storeOverride: store, assetScope: Set(snapshot.assets.map(\.id)))
            } else { Text(error ?? "准备浏览测试") }
        }.task {
            guard store == nil else { return }
            let gateway = PhotoLibraryGateway()
            if await !gateway.snapshot().permission.canRead { _ = await gateway.requestAccess() }
            let library = await gateway.snapshot()
            let randomPreview = ProcessInfo.processInfo.arguments.contains("--random-preview-test")
            let filenames = ["landscape.jpg", "clip.mp4", "portrait-smile.jpg"] + (randomPreview ? ["landscape-near.jpg"] : [])
            var matching: [String: String] = [:]
            PHAsset.fetchAssets(withLocalIdentifiers: library.assets.map(\.id), options: nil).enumerateObjects { asset, _, _ in
                for resource in PHAssetResource.assetResources(for: asset) where filenames.contains(resource.originalFilename) {
                    if matching[resource.originalFilename] == nil { matching[resource.originalFilename] = asset.localIdentifier }
                }
            }
            let ids = filenames.compactMap { matching[$0] }
            guard ids.count == filenames.count else { error = "请安装合成测试素材"; return }
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HomeNavigation-\(UUID())")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let store = try LocalStateStore(url: directory.appendingPathComponent("Intent.store"))
                if !continuity { try await store.saveSession(.init(id: UUID(), assetIDs: ids, cursor: 0, updatedAt: .now)) }
                var scoped = library.assets.filter { ids.contains($0.id) }
                if randomPreview {
                    // Two distinct memories over generated media for the real
                    // home -> review -> dismiss preview lifecycle test.
                    let day = Calendar.current.date(from: DateComponents(year: 2025, month: 9, day: 1, hour: 12))!
                    scoped = scoped.map { asset in
                        let index = ids.firstIndex(of: asset.id)!
                        let date = day.addingTimeInterval(Double(index / 2) * 86400 + Double(index % 2) * 60)
                        return PhotoAssetSnapshot(id: asset.id, kind: asset.kind, creationDate: date, modificationDate: asset.modificationDate,
                            width: asset.width, height: asset.height, duration: asset.duration, isFavorite: asset.isFavorite, isLivePhoto: asset.isLivePhoto)
                    }
                } else if continuity, let day = ReviewTimeline().lastYearDate(relativeTo: .now) {
                    // Deterministic metadata over actual generated media IDs, not a private library.
                    let offsets = [0, 1, -1]
                    scoped = scoped.map { asset in
                        let date = Calendar.current.date(byAdding: .day, value: offsets[ids.firstIndex(of: asset.id)!], to: day)!
                        return PhotoAssetSnapshot(id: asset.id, kind: asset.kind, creationDate: date, modificationDate: asset.modificationDate,
                            width: asset.width, height: asset.height, duration: asset.duration, isFavorite: asset.isFavorite, isLivePhoto: asset.isLivePhoto)
                    }
                }
                snapshot = .init(permission: library.permission, assets: scoped, sharedLibraryMembershipVerified: library.sharedLibraryMembershipVerified)
                self.store = store
            } catch { self.error = "测试会话准备失败" }
        }
    }
}
#endif
