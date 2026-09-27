import SwiftUI

// F009 real navigation destination. F010 adds the immersive gesture composition.
struct ReviewEntryView: View {
    let review: ReviewSession
    @State private var loader = PhotoLoader()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch review.current {
            case .available(let asset):
                if asset.kind == .video { VideoReviewView(assetID: asset.id, showControls: true) }
                else {
                    switch loader.state {
                    case .ready(let image): PhotoContentView(image: image)
                    case .loading(let progress): ProgressView(value: progress).tint(.white)
                    case .offline: retry("当前离线，连接后重试")
                    case .needsDownload: retry("从 iCloud 加载照片")
                    case .failed, .unavailable: retry("照片暂不可用，重试")
                    case .idle: ProgressView().tint(.white)
                    }
                }
            case .unavailable(let message): Text(message).foregroundStyle(.white).padding()
            case .noSession: Text("暂无回顾片段").foregroundStyle(.white)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("返回回顾", systemImage: "chevron.left") { dismiss() }.buttonStyle(.glass).padding().accessibilityIdentifier("review.back")
        }
        .task(id: review.currentID) {
            loader.cancel()
            if case .available(let asset) = review.current, asset.kind == .photo {
                loader.load(PhotoRequestKey(assetID: asset.id, version: asset.modificationDate, width: 1600, height: 2400))
            }
        }
        .onDisappear { loader.releaseMemory() }
    }
    private func retry(_ title: String) -> some View { Button(title) { loader.retry() }.buttonStyle(.glass).padding() }
}
