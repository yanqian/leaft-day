#if DEBUG
import SwiftUI
import Photos

struct ReviewTestHost: View {
    var enableFavorites = false
    var enablePending = false
    @State private var pending: PendingCoordinator?
    @State private var favorites: FavoriteCoordinator?
    @State private var review: ReviewSession?
    @State private var intents: [ReviewIntent] = []
    @State private var failure: String?
    @State private var faultStore: PendingFaultTestStore?
    var body: some View {
        Group {
            if let review {
                ReviewEntryView(review: review, favorites: favorites, pending: pending) { intents.append($0) }
                    .overlay(alignment: .topLeading) {
                        Text("cursor=\(review.state?.cursor ?? -1) intents=\(intents.count) kind=\(intents.last?.kind.rawValue ?? "none") target=\(intents.last?.assetID ?? "none") current=\(review.currentID ?? "none") firstFavorite=\(review.snapshot.assets.first { $0.id == review.state?.assetIDs.first }?.isFavorite ?? false) pending=\(pending?.items.count ?? 0) firstPending=\(pending?.contains(review.state?.assetIDs.first) ?? false)")
                            .font(.caption2).foregroundStyle(.yellow).lineLimit(3)
                            .accessibilityIdentifier("review.test-state").allowsHitTesting(false).padding(.top, 64)
                    }
            } else { Text(failure ?? "准备测试片段") }
        }.onChange(of: review?.isComplete) { _, complete in if complete == true { faultStore?.armOnce() } }
        .task {
            do {
                let gateway = PhotoLibraryGateway()
                if await !gateway.snapshot().permission.canRead { _ = await gateway.requestAccess() }
                var snapshot = await gateway.snapshot()
                var eligible = snapshot.assets.filter { $0.kind == .photo }
                if enableFavorites || enablePending {
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
                if !ProcessInfo.processInfo.arguments.contains("--preserve-review-store"), FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let disk = try LocalStateStore(url: directory.appendingPathComponent("Intent.store"))
                var store: any LocalStateRepository = disk
                if enablePending, let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--pending-failure=") }) {
                    let injected = PendingFaultTestStore(base: disk, fault: argument.hasSuffix("=undo") ? .undo : .position)
                    faultStore = injected; store = injected
                }
                let session = ReviewSession(store: store)
                if enableFavorites || enablePending { favorites = FavoriteCoordinator(store: store) }
                if enablePending { pending = PendingCoordinator(store: store); try await pending?.reload() }
                session.updateLibrary(snapshot)
                if let pending { session.updatePending(pending.items) }
                if enablePending && ProcessInfo.processInfo.arguments.contains("--preserve-review-store") { try await session.restore() }
                if session.state == nil {
                    let single = enablePending && ProcessInfo.processInfo.arguments.contains("--pending-anniversary-test")
                    try await session.start(ReviewSegment(assetIDs: single ? [photos[0].id] : photos.map(\.id) + [video.id], start: photos.first?.creationDate, end: video.creationDate), mode: single ? .anniversary : .segment)
                }
                review = session
            } catch { failure = "测试片段准备失败：\(error)" }
        }
    }
}
#endif
