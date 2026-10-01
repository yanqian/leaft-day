import SwiftUI

struct PhotoAccessWelcomeView: View {
    let permission: LibraryPermission
    let loading: Bool
    let requesting: Bool
    let request: () -> Void
    let openSettings: () -> Void
    let retry: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PhotoPaletteBackground()
                VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: typeSize.isAccessibilitySize ? 20 : 28) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24).fill(.white.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.4), lineWidth: 0.7))
                                .frame(width: 104, height: 112).rotationEffect(.degrees(-13)).offset(x: -12, y: -8)
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 46, weight: .light)).frame(width: 104, height: 112)
                                .photoGlass(radius: 24)
                        }.frame(height: 142).accessibilityHidden(true)
                        VStack(spacing: 14) {
                            Text("时光").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                            Text("回顾照片与视频").font(.title3).multilineTextAlignment(.center)
                        }
                        VStack(spacing: 14) {
                            if loading { ProgressView("正在读取照片访问状态").accessibilityIdentifier("permission.loading") }
                            else {
                                Text(permission.guidance).font(.body).multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("permission.guidance")
                                if permission == .notDetermined {
                                    Text("只在你授权的范围内浏览").font(.footnote).multilineTextAlignment(.center)
                                }
                            }
                        }.frame(maxWidth: .infinity).padding(22).photoGlass()
                    }.padding(.horizontal, 24).padding(.vertical, 24)
                        .frame(maxWidth: 520).frame(maxWidth: .infinity)

                }.clipped().accessibilityIdentifier("welcome.scroll")
                    if !loading {
                        Group {
                            if permission == .notDetermined {
                                Button(action: request) { Label("允许访问照片", systemImage: "photo") }
                                    .accessibilityIdentifier("permission.request").disabled(requesting)
                            } else if permission == .denied { Button("打开设置", action: openSettings) }
                            else if permission == .unknown { Button("重试", action: retry) }
                        }.buttonStyle(PhotoGlassButtonStyle())
                            .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 22).frame(maxWidth: 520)
                    }
                }
            }.photoPage()
        }
    }
}
