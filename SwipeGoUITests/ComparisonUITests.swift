import XCTest

@MainActor final class ComparisonUITests: XCTestCase {
    func testMultiKeepZoomZeroKeepSkipAndSave() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--comparison-test-host", "-AppleLanguages", "(en)"]; app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["comparison.keep.1"].waitForExistence(timeout: 10))
        app.buttons["comparison.zoom.1"].tap()
        XCTAssertTrue(app.buttons["comparison.zoom-toggle"].waitForExistence(timeout: 5)); app.buttons["comparison.zoom-toggle"].tap()
        app.buttons["comparison.zoom-close"].tap()
        for i in 1...3 { app.buttons["comparison.keep.\(i)"].tap() }
        XCTAssertFalse(app.buttons["comparison.confirm"].isEnabled)
        app.buttons["comparison.keep.1"].tap(); app.buttons["comparison.keep.2"].tap()
        app.buttons["comparison.confirm"].tap()
        XCTAssertTrue(app.staticTexts["comparison.saved"].waitForExistence(timeout: 5))
        app.buttons["comparison.close"].tap()
        XCTAssertTrue(app.staticTexts["comparison.test-state"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["comparison.test-state"].label, "pending=1")
        app.buttons["打开比较"].tap(); app.buttons["comparison.skip"].tap()
        XCTAssertEqual(app.staticTexts["comparison.test-state"].label, "pending=1")
        app.buttons["打开比较"].tap(); app.buttons["comparison.keep-all"].tap()
        XCTAssertTrue(app.staticTexts["comparison.saved"].waitForExistence(timeout: 5)); app.buttons["comparison.close"].tap()
        XCTAssertEqual(app.staticTexts["comparison.test-state"].label, "pending=0")
    }
}
