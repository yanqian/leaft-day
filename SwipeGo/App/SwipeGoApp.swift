import SwiftUI

@main
struct SwipeGoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentUnavailableView {
                Label("时光", systemImage: "photo.stack")
            } description: {
                Text("回顾照片与视频")
            }
            .accessibilityIdentifier("app.root")
        }
    }
}
