#if DEBUG
import SwiftUI

/// Pure presentation of the production card. No Photos request or test data write.
struct HomeCoverStateTestHost: View {
    private var state: HomeCoverLoader.State {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--cover-loading") { return .loading(nil) }
        if arguments.contains("--cover-downloading") { return .loading(0.4) }
        if arguments.contains("--cover-offline") { return .offline }
        if arguments.contains("--cover-unavailable") { return .unavailable }
        return .empty
    }
    var body: some View {
        ZStack {
            PhotoPaletteBackground()
            ScrollView {
                Group {
                    if ProcessInfo.processInfo.arguments.contains("--cover-hero") {
                        HomeHeroCardContent(state: state, title: "2025年9月29日 – 10月1日", summary: "剩余 12 项照片与视频", action: "继续回顾", minimumHeight: 380)
                    } else {
                        HomePhotoCardContent(state: state, title: "去年的今天", subtitle: "再看这一日", emptyText: "这一天暂无照片", minimumHeight: 320)
                    }
                }.padding(20)
            }
        }.photoPage()
    }
}
#endif
