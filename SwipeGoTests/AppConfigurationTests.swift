import XCTest
@testable import SwipeGo

final class AppConfigurationTests: XCTestCase {
    func testApplicationBundleTargetsIPhone() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.armstrong.swipego")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int], [1])
    }
}
