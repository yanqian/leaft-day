import SwiftUI

/// Bundled decorative art: available before permission and after photos are deleted.
/// It makes no PhotoKit request and never implies a deleted asset is still cached.
struct CoastalBackdrop: View {
    static let image = Bundle.main.url(forResource: "CoastalAtmosphere", withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.08, green: 0.20, blue: 0.22)
                if let image = Self.image {
                    Image(uiImage: image).renderingMode(.original).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                Color.black.opacity(0.28)
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
