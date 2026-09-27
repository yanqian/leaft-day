import SwiftUI
import AVFoundation
import Photos

enum VideoResourceEvent { case progress(Double), item(AVPlayerItem), offline, unavailable, failed(String) }
@MainActor protocol VideoTransport: AnyObject {
    func request(assetID: String, receive: @escaping @MainActor (VideoResourceEvent) -> Void) -> UUID
    func cancel(_ token: UUID)
}

@MainActor final class NativeVideoTransport: VideoTransport {
    private let manager = PHImageManager()
    private var requests: [UUID: PHImageRequestID] = [:]
    isolated deinit { for id in requests.values { manager.cancelImageRequest(id) } }
    func request(assetID: String, receive: @escaping @MainActor (VideoResourceEvent) -> Void) -> UUID {
        let token = UUID()
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject,
              asset.mediaType == .video, !asset.isHidden, asset.sourceType == .typeUserLibrary else {
            receive(.unavailable); return token
        }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        options.progressHandler = { progress, _, _, _ in
            Task { @MainActor [weak self] in
                guard self?.requests[token] != nil else { return }; receive(.progress(progress))
            }
        }
        let id = manager.requestPlayerItem(forVideo: asset, options: options) { item, info in
            let error = info?[PHImageErrorKey] as? NSError
            let offline = error?.domain == NSURLErrorDomain && error?.code == NSURLErrorNotConnectedToInternet
            let message = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, requests.removeValue(forKey: token) != nil else { return }
                if let item { receive(.item(item)) }
                else if offline { receive(.offline) }
                else if let message { receive(.failed(message)) }
                else { receive(.unavailable) }
            }
        }
        requests[token] = id
        return token
    }
    func cancel(_ token: UUID) { if let id = requests.removeValue(forKey: token) { manager.cancelImageRequest(id) } }
}

@MainActor @Observable final class VideoPlayback {
    enum State { case idle, loading(Double?), ready, offline, unavailable, failed(String) }
    private(set) var state: State = .idle
    private(set) var releaseCount = 0
    private(set) var isPlaying = false
    private(set) var isMuted = true
    private(set) var position = 0.0
    private(set) var duration = 0.0
    private(set) var assetID: String?
    private(set) var player: AVPlayer?
    private var generation = UUID()
    @ObservationIgnored private let transport: any VideoTransport
    @ObservationIgnored private var request: UUID?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var periodic: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    init(transport: any VideoTransport = NativeVideoTransport()) { self.transport = transport }

    func open(_ id: String) {
        stop()
        assetID = id; state = .loading(nil)
        let generation = self.generation
        request = transport.request(assetID: id) { [weak self] event in
            guard let self, self.generation == generation, assetID == id else { return }
            switch event {
            case .progress(let progress): state = .loading(progress)
            case .offline: state = .offline
            case .unavailable: state = .unavailable
            case .failed(let error): state = .failed(error)
            case .item(let item): attach(item, generation: generation)
            }
        }
    }

    private func attach(_ item: AVPlayerItem, generation: UUID) {
        let player = AVPlayer(playerItem: item)
        player.isMuted = true; isMuted = true; self.player = player
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            let error = item.error?.localizedDescription
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                if status == .readyToPlay {
                    self.state = .ready; self.duration = self.finiteDuration(item.duration.seconds)
                    player.play(); self.isPlaying = true
                } else if status == .failed {
                    self.state = .failed(error ?? "视频无法播放"); player.pause(); self.isPlaying = false
                }
            }
        }
        periodic = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.position = max(0, time.seconds.isFinite ? time.seconds : 0)
                self.duration = self.finiteDuration(player.currentItem?.duration.seconds ?? 0)
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }; self.isPlaying = false
            }
        }
    }
    private func finiteDuration(_ seconds: Double) -> Double { seconds.isFinite ? max(0, seconds) : 0 }
    func togglePlayback() {
        guard case .ready = state, let player else { return }
        if isPlaying { player.pause(); isPlaying = false }
        else { if duration > 0 && position >= duration - 0.1 { seek(to: 0) }; player.play(); self.isPlaying = true }
    }
    func toggleMute() { isMuted.toggle(); player?.isMuted = isMuted }
    func seek(to seconds: Double) {
        guard case .ready = state, seconds.isFinite else { return }
        let target = min(max(0, seconds), duration)
        player?.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        position = target
    }
    func retry() { if let assetID { open(assetID) } }
    func stop() {
        if player != nil || request != nil { releaseCount += 1 }
        generation = UUID()
        if let request { transport.cancel(request) }; request = nil
        player?.pause()
        if let periodic { player?.removeTimeObserver(periodic) }; periodic = nil
        statusObservation?.invalidate(); statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        player?.replaceCurrentItem(with: nil); player = nil
        isPlaying = false; position = 0; duration = 0; assetID = nil; state = .idle
    }
    isolated deinit {
        if let request { transport.cancel(request) }
        player?.pause()
        if let periodic { player?.removeTimeObserver(periodic) }
        statusObservation?.invalidate()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        player?.replaceCurrentItem(with: nil)
    }
}

private struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer?
    final class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
    }
    func makeUIView(context: Context) -> Surface { Surface() }
    func updateUIView(_ view: Surface, context: Context) {
        let layer = view.layer as! AVPlayerLayer
        layer.videoGravity = .resizeAspect; layer.player = player
    }
    static func dismantleUIView(_ view: Surface, coordinator: ()) { (view.layer as! AVPlayerLayer).player = nil }
}

struct VideoReviewView: View {
    let assetID: String
    var showControls: Bool
    var onMediaDrag: (CGSize) -> Void
    @State private var playback: VideoPlayback
    init(assetID: String, showControls: Bool, playback: VideoPlayback = VideoPlayback(), onMediaDrag: @escaping (CGSize) -> Void = { _ in }) {
        self.assetID = assetID; self.showControls = showControls; self.onMediaDrag = onMediaDrag; _playback = State(initialValue: playback)
    }
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(spacing: 0) {
            VideoSurface(player: playback.player)
                .background(.black)
                .contentShape(Rectangle())
                .onTapGesture { playback.togglePlayback() }
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { onMediaDrag($0.translation) })
                .accessibilityIdentifier("video.surface")
                .accessibilityLabel("视频画面")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { playback.togglePlayback() }
            if showControls {
                HStack {
                    Button(playback.isPlaying ? "暂停" : "播放", systemImage: playback.isPlaying ? "pause.fill" : "play.fill") { playback.togglePlayback() }
                    Slider(value: Binding(get: { playback.position }, set: { playback.seek(to: $0) }), in: 0...max(playback.duration, 0.01))
                        .accessibilityLabel("视频进度").accessibilityIdentifier("video.progress")
                    Button(playback.isMuted ? "开启声音" : "静音", systemImage: playback.isMuted ? "speaker.slash" : "speaker.wave.2") { playback.toggleMute() }
                }
                .labelStyle(.iconOnly).padding().glassEffect()
                // Controls are outside the tappable media surface; F010 routes swipes
                // only through the media region, never this slider/control row.
            }
            switch playback.state {
            case .loading(let progress): ProgressView(value: progress).accessibilityLabel("正在加载视频")
            case .offline, .unavailable, .failed: Button("视频暂不可用，重试") { playback.retry() }
            default: EmptyView()
            }
        }
        .onAppear { playback.open(assetID) }
        .onChange(of: assetID) { _, id in playback.open(id) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { if playback.assetID != assetID { playback.open(assetID) } } else { playback.stop() } }
        .onDisappear { playback.stop() }
    }
}
