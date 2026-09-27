#if DEBUG
import SwiftUI
import Photos

struct ReviewTestHost: View {
    var enableFavorites = false
    @State private var favorites: FavoriteCoordinator?
    @State private var review: ReviewSession?
    @State private var intents: [ReviewIntent] = []
    @State private var failure: String?
    var body: some View {
        Group {
            if let review {
                ReviewEntryView(review: review, favorites: favorites) { intents.append($0) }
                    .overlay(alignment: .topLeading) {
                        Text("cursor=\(review.state?.cursor ?? -1) intents=\(intents.count) kind=\(intents.last?.kind.rawValue ?? "none") target=\(intents.last?.assetID ?? "none") current=\(review.currentID ?? "none") firstFavorite=\(review.snapshot.assets.first { $0.id == review.state?.assetIDs.first }?.isFavorite ?? false)")
                            .font(.caption2).foregroundStyle(.yellow).lineLimit(3)
                            .accessibilityIdentifier("review.test-state").allowsHitTesting(false)
                    }
            } else { Text(failure ?? "准备测试片段") }
        }.task {
            do {
                let gateway = PhotoLibraryGateway()
                if await !gateway.snapshot().permission.canRead { _ = await gateway.requestAccess() }
                var snapshot = await gateway.snapshot()
                var eligible = snapshot.assets.filter { $0.kind == .photo }
                if enableFavorites {
                    var fixtureIDs = Set<String>()
                    PHAsset.fetchAssets(withLocalIdentifiers: eligible.map(\.id), options: nil).enumerateObjects { asset, _, _ in
                        if PHAssetResource.assetResources(for: asset).contains(where: { ["landscape.jpg", "portrait-smile.jpg"].contains($0.originalFilename) }) { fixtureIDs.insert(asset.localIdentifier) }
                    }
                    eligible = eligible.filter { fixtureIDs.contains($0.id) }
                    let writer = NativeFavoriteWriter()
                    for asset in eligible where asset.isFavorite { _ = try await writer.setFavorite(id: asset.id, value: false, expected: asset) }
                    snapshot = await gateway.snapshot()
                    eligible = snapshot.assets.filter { fixtureIDs.contains($0.id) }
                }
                let photos = Array(eligible.prefix(2))
                guard photos.count == 2, let video = snapshot.assets.first(where: { $0.kind == .video }) else { failure = "测试需要两张照片和视频"; return }
                let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ReviewUITestOnly")
                if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let store = try LocalStateStore(url: directory.appendingPathComponent("Intent.store"))
                let session = ReviewSession(store: store)
                if enableFavorites { favorites = FavoriteCoordinator(store: store) }
                session.updateLibrary(snapshot)
                try await session.start(ReviewSegment(assetIDs: photos.map(\.id) + [video.id], start: photos.first?.creationDate, end: video.creationDate))
                review = session
            } catch { failure = "测试片段准备失败：\(error)" }
        }
    }
}
#endif
