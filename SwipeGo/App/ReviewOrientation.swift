import UIKit

/// Home stays portrait; the review follows the system's device orientation policy.
@MainActor enum ReviewOrientation {
    private(set) static var supported: UIInterfaceOrientationMask = .portrait

    static func setReviewActive(_ active: Bool) {
        supported = active ? .allButUpsideDown : .portrait
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            guard scene.activationState == .foregroundActive,
                  let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { continue }
            var controller: UIViewController? = root
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
            // Do not force a landscape orientation or bypass rotation lock on entry.
            // Returning home explicitly restores its sole supported orientation.
            if !active { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        }
    }
}

final class SwipeGoAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        ReviewOrientation.supported
    }
}
