import SwiftUI

struct PhotoPaletteBackground: View {
    var palette: PhotoPalette = .neutral
    var body: some View {
        let colors = palette.colors.count >= 3 ? palette.colors : PhotoPalette.neutral.colors
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [colors[2].color, colors[0].color], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [colors[0].color, colors[0].color.opacity(0)], center: .topLeading,
                               startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.95)
                RadialGradient(colors: [colors[1].color, colors[1].color.opacity(0)], center: .bottomTrailing,
                               startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.85)
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct PhotoColorBackdrop: View {
    var image: UIImage? = nil
    var asset: PhotoAssetSnapshot? = nil
    @State private var model = PhotoPaletteModel()
    private struct Identity: Equatable { let image: ObjectIdentifier?; let asset: PhotoAssetSnapshot? }
    var body: some View {
        PhotoPaletteBackground(palette: model.palette)
            .task(id: Identity(image: image.map(ObjectIdentifier.init), asset: asset)) {
                if let image { model.use(image) } else { model.load(asset) }
            }
            .onDisappear { model.cancel() }
    }
}

enum PhotoTheme {
    static let ink = Color(red: 0.09, green: 0.22, blue: 0.24)
    static let secondary = Color(red: 0.20, green: 0.30, blue: 0.31)
    static let warning = Color(red: 0.42, green: 0.24, blue: 0.04)
    static let success = Color(red: 0.08, green: 0.32, blue: 0.22)
    static let destructive = Color(red: 0.56, green: 0.13, blue: 0.11)
}

struct PhotoGlass: ViewModifier {
    var radius: CGFloat = 26
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var opaque: Bool {
        #if DEBUG
        reduceTransparency || ProcessInfo.processInfo.arguments.contains("--reduced-transparency-test")
        #else
        reduceTransparency
        #endif
    }
    @ViewBuilder func body(content: Content) -> some View {
        if opaque {
            content.background(Color(red: 0.92, green: 0.96, blue: 0.94), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(PhotoTheme.ink.opacity(0.18)).allowsHitTesting(false))
        } else {
            content.background {
                RoundedRectangle(cornerRadius: radius).fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: radius))
                    .opacity(0.38)
            }
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.8), lineWidth: 0.7).allowsHitTesting(false))
                .shadow(color: PhotoTheme.ink.opacity(0.07), radius: 12, y: 6)
        }
    }
}
extension View {
    func photoGlass(radius: CGFloat = 26) -> some View { modifier(PhotoGlass(radius: radius)) }
    func photoPage() -> some View { foregroundStyle(PhotoTheme.ink).tint(PhotoTheme.ink).environment(\.colorScheme, .light) }
}

struct PhotoGlassButtonStyle: ButtonStyle {
    var destructive = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 16).padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 30))
            .foregroundStyle(destructive ? PhotoTheme.destructive : PhotoTheme.ink)
            .background(destructive ? Color.red.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 30))
            .photoGlass(radius: 30).opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
    }
}

struct PhotoStatusCard: View {
    let title: String
    let message: String
    var icon = "info.circle"
    var color: Color = PhotoTheme.ink
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 44, weight: .light)).foregroundStyle(color).accessibilityHidden(true)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            if !message.isEmpty { Text(message).font(.callout).foregroundStyle(PhotoTheme.secondary).multilineTextAlignment(.center) }
        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity).padding(26).photoGlass(radius: 30)
    }
}
