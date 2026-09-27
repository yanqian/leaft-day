#if DEBUG
import SwiftUI

// Local UI verification surface only. Not part of normal app navigation.
struct VideoTestHost: View {
    @State private var playback = VideoPlayback()
    @State private var assetID: String?
    @State private var visible = true
    @State private var session = UUID()
    @State private var retired: [VideoPlayback] = []
    @State private var starts = 0
    @State private var mediaActions = 0
    var body: some View {
        VStack {
            if let assetID, visible {
                VideoReviewView(assetID: assetID, showControls: true, playback: playback, onMediaDrag: { _ in mediaActions += 1 })
                    .id(session)
            } else { Color.clear }
            Text("\(playback.isPlaying ? "playing" : "paused") \(playback.isMuted ? "muted" : "sound") \(playback.player == nil ? "released" : "attached") started=\(starts > 0) stops=\(playback.releaseCount + retired.reduce(0) { $0 + $1.releaseCount }) retiredReleased=\(retired.allSatisfy { $0.player == nil }) actions=\(mediaActions)")
                .accessibilityIdentifier("video.state")
            TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                Text(String(format: "%.2f", playback.player?.currentTime().seconds ?? 0))
                    .accessibilityIdentifier("video.actual-time")
            }
            Button("切换会话") { retired.append(playback); playback = VideoPlayback(); session = UUID() }
            Button(visible ? "关闭视频" : "打开视频") { visible.toggle() }
        }
        .task {
            if await !PhotoLibraryGateway().snapshot().permission.canRead {
                _ = await PhotoLibraryGateway().requestAccess()
            }
            assetID = await PhotoLibraryGateway().snapshot().assets.first { $0.kind == .video }?.id
        }
        .onChange(of: playback.isPlaying) { _, playing in if playing { starts += 1 } }

    }
}
#endif
