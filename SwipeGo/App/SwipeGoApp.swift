import SwiftUI

@main
struct SwipeGoApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--reconciliation-test-host") { DeletionReviewTestHost(interrupted: true) }
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
