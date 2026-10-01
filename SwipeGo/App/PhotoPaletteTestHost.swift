#if DEBUG
import SwiftUI

struct PhotoPaletteTestHost: View {
    @State private var palette: PhotoPalette = .neutral
    var body: some View {
        ZStack {
            PhotoPaletteBackground(palette: palette)
            ScrollView {
                VStack(spacing: 20) {
                    Text("照片取色").font(.largeTitle.bold())
                    PhotoStatusCard(title: "已删除 11 项", message: "系统已确认本次删除\n待删清单已清空", icon: "checkmark.circle", color: PhotoTheme.success)
                    Text(palette.token).font(.caption2).accessibilityIdentifier("palette.token")
                    ForEach(["海蓝", "草木", "暖桃", "默认"], id: \.self) { name in
                        Button(name) { choose(name) }.buttonStyle(PhotoGlassButtonStyle())
                    }
                }.padding(24)
            }
        }.photoPage()
    }
    private func choose(_ name: String) {
        guard name != "默认" else { palette = .neutral; return }
        let color: UIColor = name == "海蓝" ? .init(red: 0.12, green: 0.55, blue: 0.8, alpha: 1)
            : name == "草木" ? .init(red: 0.30, green: 0.58, blue: 0.20, alpha: 1)
            : .init(red: 0.85, green: 0.36, blue: 0.29, alpha: 1)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
            color.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor(red: 0.68, green: 0.64, blue: 0.38, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 42, width: 64, height: 22))
            UIColor(red: 0.24, green: 0.58, blue: 0.50, alpha: 1).setFill()
            ctx.fill(CGRect(x: 42, y: 0, width: 22, height: 42))
        }
        palette = PhotoPalette.extract(from: image)
    }
}
#endif
