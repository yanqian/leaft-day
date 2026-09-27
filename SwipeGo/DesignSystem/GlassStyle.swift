import SwiftUI

struct GlassPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat = 24
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
        } else { content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius)) }
    }
}
extension View {
    func glassPanel(radius: CGFloat = 24) -> some View { modifier(GlassPanel(radius: radius)) }
}
struct RecollectionBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(uiColor: .systemBackground), Color.cyan.opacity(0.15), Color.orange.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
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
