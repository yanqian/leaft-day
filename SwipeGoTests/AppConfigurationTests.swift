import XCTest
import UIKit
@testable import SwipeGo

final class AppConfigurationTests: XCTestCase {
    func testApplicationBundleTargetsIPhone() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.armstrong.swipego")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "LeafDay")
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        XCTAssertEqual(primary?["CFBundleIconName"] as? String, "AppIcon")
        XCTAssertNotNil(UIImage(named: "LeafDayMark"))
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int], [1])
    }
}
