import SwiftUI

@main
struct SwipeGoApp: App {
    @UIApplicationDelegateAdaptor(SwipeGoAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--palette-test-host") { PhotoPaletteTestHost() }
            else if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--device-acceptance=") }),
               let value = argument.split(separator: "=").last, let runID = UUID(uuidString: String(value)) { DeviceAcceptanceHost(runID: runID) }
            else if let mode = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--review-state=") })?.split(separator: "=").last { ReviewStateTestHost(mode: String(mode)) }
            else if ProcessInfo.processInfo.arguments.contains("--continuity-test-host") { HomeNavigationTestHost(continuity: true) }
            else if ProcessInfo.processInfo.arguments.contains("--home-navigation-test-host") { HomeNavigationTestHost() }
            else if ProcessInfo.processInfo.arguments.contains("--history-test-host") { DeletionHistoryTestHost() }
            else if ProcessInfo.processInfo.arguments.contains("--home-cover-test-host") { HomeCoverStateTestHost() }
            else if ProcessInfo.processInfo.arguments.contains("--reconciliation-test-host") { DeletionReviewTestHost(interrupted: true) }
            else if ProcessInfo.processInfo.arguments.contains("--deletion-result-test-host") { DeletionResultTestHost() }
            else if ProcessInfo.processInfo.arguments.contains("--deletion-test-host") { DeletionTestHost() }
            else if ProcessInfo.processInfo.arguments.contains("--deletion-review-test-host") { DeletionReviewTestHost() }
            else if ProcessInfo.processInfo.arguments.contains("--comparison-test-host") { ComparisonTestHost() }
            else if ProcessInfo.processInfo.arguments.contains("--video-test-host") { VideoTestHost() }
            else if ProcessInfo.processInfo.arguments.contains("--pending-test-host") { ReviewTestHost(enablePending: true) }
            else if ProcessInfo.processInfo.arguments.contains("--favorite-test-host") { ReviewTestHost(enableFavorites: true) }
            else if ProcessInfo.processInfo.arguments.contains("--review-test-host") { ReviewTestHost() }
            else { LibraryAccessView() }
            #else
            LibraryAccessView()
            #endif
        }
    }
}
