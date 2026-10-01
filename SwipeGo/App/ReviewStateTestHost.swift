#if DEBUG
import SwiftUI

/// Synthetic missing IDs exercise real presentation paths without reading media.
struct ReviewStateTestHost: View {
    let mode: String
    @State private var review: ReviewSession?
    @State private var pending: PendingCoordinator?
    @State private var error: String?
    @State private var presented = false
    var body: some View {
        Group {
            if let review {
                if mode == "comparison", let pending { ComparisonView(groups: [], assets: [], pending: pending) }
                else if ProcessInfo.processInfo.arguments.contains("--state-presentation-test") {
                    Button("打开状态") { presented = true }.fullScreenCover(isPresented: $presented) { ReviewEntryView(review: review) }
                } else { ReviewEntryView(review: review) }
            } else { Text(error ?? "准备状态预览") }
        }.task {
            #if targetEnvironment(simulator)
            do {
                let store = try LocalStateStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".store"))
                let session = ReviewSession(store: store)
                let asset = PhotoAssetSnapshot(id: "synthetic-missing-asset", kind: mode == "video" ? .video : .photo,
                    creationDate: nil, modificationDate: nil, width: 800, height: 600, duration: 0, isFavorite: false, isLivePhoto: false)
                session.updateLibrary(LibrarySnapshot(permission: .full, assets: [asset], sharedLibraryMembershipVerified: false))
                if mode == "completed" {
                    let intent = PendingIntent(assetID: asset.id, groupID: nil, markedAt: .now)
                    try await store.markPending(intent); session.updatePending([intent])
                }
                if mode != "empty" { try await session.start(ReviewSegment(assetIDs: [asset.id], start: nil, end: nil)) }
                if mode == "unavailable" { session.updateLibrary(LibrarySnapshot(permission: .full, assets: [], sharedLibraryMembershipVerified: false)) }
                pending = PendingCoordinator(store: store); review = session
            } catch { self.error = String(describing: error) }
            #else
            error = "状态测试仅在模拟器中运行"
            #endif
        }
    }
}
#endif
