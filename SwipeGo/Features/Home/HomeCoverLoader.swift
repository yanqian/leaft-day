import SwiftUI

/// At most three photos from this segment; never substitutes a video or another date.
@MainActor @Observable final class HomeCoverLoader {
    enum State { case empty, loading(Double?), ready(UIImage), offline, unavailable }
    private(set) var state: State = .empty
    private var candidates: [PhotoAssetSnapshot] = []
    private var offline = false
    private var generation = UUID()
    private var attempt = UUID()
    @ObservationIgnored private let transport: any PhotoTransport
    @ObservationIgnored private let cache: PhotoMemoryCache
    @ObservationIgnored private var request: UUID?
    var image: UIImage? { if case .ready(let image) = state { image } else { nil } }

    init(transport: any PhotoTransport = NativePhotoTransport(), cache: PhotoMemoryCache = PhotoMemoryCache()) {
        self.transport = transport; self.cache = cache
    }
    func load(_ assets: [PhotoAssetSnapshot]) {
        cancel(); offline = false
        var seen = Set<String>()
        candidates = Array(assets.filter { $0.kind == .photo && seen.insert($0.id).inserted }.prefix(3))
        guard !candidates.isEmpty else { state = .empty; return }
        loadCandidate(0, generation: generation)
    }
    private func loadCandidate(_ index: Int, generation: UUID) {
        guard self.generation == generation else { return }
        guard candidates.indices.contains(index) else { state = offline ? .offline : .unavailable; return }
        let attempt = UUID(); self.attempt = attempt
        let asset = candidates[index]
        let key = PhotoRequestKey(assetID: asset.id, version: asset.modificationDate, width: 800, height: 1000)
        if let image = cache.image(for: key) { state = .ready(image); return }
        state = .loading(nil)
        request = transport.request(key, network: !offline) { [weak self] event in
            // Defer even a synchronous transport callback until its request token is installed.
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation, self.attempt == attempt else { return }
                switch event {
                case .progress(let value): state = .loading(value)
                case .image(let image): request = nil; cache.insert(image, for: key); state = .ready(image)
                case .offline:
                    request = nil; offline = true; loadCandidate(index + 1, generation: generation)
                case .unavailable, .failed, .needsDownload:
                    request = nil; loadCandidate(index + 1, generation: generation)
                }
            }
        }
    }
    func cancel() {
        generation = UUID()
        if let request { transport.cancel(request) }
        request = nil; state = .empty
    }
    isolated deinit { if let request { transport.cancel(request) } }
}

struct HomeHeroCardContent: View {
    let state: HomeCoverLoader.State
    let title: String
    let summary: String
    let action: String
    let minimumHeight: CGFloat
    @Environment(\.dynamicTypeSize) private var typeSize
    private var hasImage: Bool { if case .ready = state { true } else { false } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 32)
            Text(title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("home.cover-title")
            if let message = state.message(emptyText: "这段时光没有照片封面") {
                Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.cover-status")
            }
            if typeSize.isAccessibilitySize {
                Text(summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                actionLabel
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    Text(summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    actionLabel
                }
            }
        }.foregroundStyle(hasImage ? .white : PhotoTheme.ink).padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: minimumHeight)
            .background {
                GeometryReader { geometry in
                    ZStack {
                        if case .ready(let image) = state {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        }
                        if hasImage { LinearGradient(colors: [.black.opacity(typeSize.isAccessibilitySize ? 0.75 : 0), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom) }
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .photoGlass(radius: 28).clipShape(RoundedRectangle(cornerRadius: 28))
            .contentShape(RoundedRectangle(cornerRadius: 28))
    }
    @ViewBuilder private var actionLabel: some View {
        if hasImage { actionText.recollectionGlass(radius: 28) }
        else { actionText.photoGlass(radius: 28) }
    }
    private var actionText: some View {
        Label(action, systemImage: "arrow.right").font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// Status lives in the same flow as the caption, never underneath it. At large
// text sizes the card grows beyond its minimum height instead of clipping.
struct HomePhotoCardContent: View {
    let state: HomeCoverLoader.State
    let title: String
    let subtitle: String
    let emptyText: String
    let minimumHeight: CGFloat
    private var image: UIImage? { if case .ready(let image) = state { return image }; return nil }
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: image == nil ? 16 : minimumHeight * 0.4)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.cover-title")
                if let message = state.message(emptyText: emptyText) {
                    Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.cover-status")
                    if case .loading(let progress) = state { ProgressView(value: progress).accessibilityHidden(true) }
                } else {
                    Text(subtitle).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .modifier(HomeCaptionGlass(overPhoto: image != nil)).padding(6)
        }.frame(maxWidth: .infinity).frame(minHeight: minimumHeight)
            .background {
                GeometryReader { geometry in
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    } else { Color.white.opacity(0.12) }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.5), lineWidth: 0.7).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

extension HomeCoverLoader.State {
    func message(emptyText: String) -> String? {
        switch self {
        case .empty: emptyText
        case .loading(let progress): progress == nil ? "正在载入照片" : "正在从 iCloud 载入"
        case .offline: "离线，封面暂不可用"
        case .unavailable: "封面暂不可用"
        case .ready: nil
        }
    }
}

struct HomeArtwork: View {
    let candidates: [PhotoAssetSnapshot]
    let title: String
    let subtitle: String
    let emptyText: String
    let height: CGFloat
    @State private var loader: HomeCoverLoader
    init(candidates: [PhotoAssetSnapshot], cache: PhotoMemoryCache, title: String, subtitle: String, emptyText: String, height: CGFloat) {
        self.candidates = candidates; self.title = title; self.subtitle = subtitle; self.emptyText = emptyText; self.height = height
        _loader = State(initialValue: HomeCoverLoader(cache: cache))
    }
    var body: some View {
        HomePhotoCardContent(state: loader.state, title: title, subtitle: subtitle, emptyText: emptyText, minimumHeight: height)
            .task(id: candidates) { loader.load(candidates) }
            .onDisappear { loader.cancel() }
    }
}

private struct HomeCaptionGlass: ViewModifier {
    let overPhoto: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if overPhoto { content.recollectionGlass(radius: 20) }
        else { content.foregroundStyle(PhotoTheme.ink).photoGlass(radius: 20) }
    }
}
