import SwiftUI

struct GlassPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat = 24
    var clear = false
    private var useOpaque: Bool {
        #if DEBUG
        reduceTransparency || ProcessInfo.processInfo.arguments.contains("--reduced-transparency-test")
        #else
        reduceTransparency
        #endif
    }
    @ViewBuilder func body(content: Content) -> some View {
        if useOpaque {
            content.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.primary.opacity(0.12)).allowsHitTesting(false))
        } else {
            content.glassEffect(clear ? .clear.tint(.white.opacity(0.12)) : .regular, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.45), lineWidth: 0.65).allowsHitTesting(false))
                .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
        }
    }
}
extension View {
    func glassPanel(radius: CGFloat = 24, clear: Bool = false) -> some View { modifier(GlassPanel(radius: radius, clear: clear)) }
}
struct RecollectionBackground: View {
    var image: UIImage? = nil
    var asset: PhotoAssetSnapshot? = nil
    @State private var backdrop = PhotoLoader(cache: PhotoMemoryCache(byteLimit: 4 * 1024 * 1024, countLimit: 1))
    private var displayedImage: UIImage? {
        if let image { return image }
        if case .ready(let image) = backdrop.state { return image }
        return nil
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                if let image = displayedImage {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 32).overlay(Color(uiColor: .systemBackground).opacity(0.58))
                } else {
                    LinearGradient(colors: [.blue.opacity(0.12), .clear, .orange.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
            .task(id: asset) {
                backdrop.cancel()
                if let asset, asset.kind == .photo {
                    backdrop.load(.init(assetID: asset.id, version: asset.modificationDate, width: 400, height: 600), network: false)
                }
            }
            .onDisappear { backdrop.releaseMemory() }
    }
}

// Explicit multiline measurement avoids compressed SwiftUI text metrics in the
// compact title/settings row while retaining native Dynamic Type and VoiceOver.
struct WrappingCaption: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
        label.font = .preferredFont(forTextStyle: .callout)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height) + 2)
    }
}

// A shared media-backed surface for review controls and deletion actions.
// The local dim layer maintains contrast over bright photos without a tall sheet.
struct RecollectionGlass: ViewModifier {
    var radius: CGFloat
    var adaptive = false
    @ViewBuilder func body(content: Content) -> some View {
        if adaptive {
            // Deletion pages have a softened system-colored backdrop, so ink follows
            // the current appearance rather than forcing white on a pale photograph.
            content.foregroundStyle(.primary).tint(.primary)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: radius))
                .glassPanel(radius: radius, clear: true)
        } else {
        content.foregroundStyle(.white).tint(.white)
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: radius))
            .glassPanel(radius: radius, clear: true)
            .environment(\.colorScheme, .dark)
        }
    }
}
extension View {
    func recollectionGlass(radius: CGFloat = 26, adaptive: Bool = false) -> some View { modifier(RecollectionGlass(radius: radius, adaptive: adaptive)) }
}
