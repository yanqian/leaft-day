#if DEBUG
import SwiftUI

struct ReviewTestHost: View {
    @State private var review: ReviewSession?
    @State private var intents: [ReviewIntent] = []
    @State private var failure: String?
    var body: some View {
        Group {
            if let review {
                ReviewEntryView(review: review) { intents.append($0) }
                    .overlay(alignment: .topLeading) {
                        Text("cursor=\(review.state?.cursor ?? -1) intents=\(intents.count) kind=\(intents.last?.kind.rawValue ?? "none") target=\(intents.last?.assetID ?? "none") current=\(review.currentID ?? "none")")
                            .font(.caption2).foregroundStyle(.yellow).lineLimit(3)
                            .accessibilityIdentifier("review.test-state").allowsHitTesting(false)
                    }
            } else { Text(failure ?? "准备测试片段") }
        }.task {
            do {
                let gateway = PhotoLibraryGateway()
                if await !gateway.snapshot().permission.canRead { _ = await gateway.requestAccess() }
                let snapshot = await gateway.snapshot()
                let photos = Array(snapshot.assets.filter { $0.kind == .photo }.prefix(2))
                guard photos.count == 2, let video = snapshot.assets.first(where: { $0.kind == .video }) else { failure = "测试需要两张照片和视频"; return }
                let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ReviewUITestOnly")
                if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let session = ReviewSession(store: try LocalStateStore(url: directory.appendingPathComponent("Intent.store")))
                session.updateLibrary(snapshot)
                try await session.start(ReviewSegment(assetIDs: photos.map(\.id) + [video.id], start: photos.first?.creationDate, end: video.creationDate))
                review = session
            } catch { failure = "测试片段准备失败：\(error)" }
        }
    }
}
#endif
