import XCTest

@MainActor
final class LaunchTests: XCTestCase {
    func testColdLaunchAndRelaunchShowRoot() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["时光"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["回顾照片与视频"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["时光"].waitForExistence(timeout: 15))
    }
}
