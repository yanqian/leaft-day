import XCTest

@MainActor final class ComparisonUITests: XCTestCase {
    func testMultiKeepZoomZeroKeepSkipAndSave() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--comparison-test-host", "-AppleLanguages", "(en)"]; app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["comparison.keep.1"].waitForExistence(timeout: 10))
        let overview = XCTAttachment(screenshot: app.screenshot()); overview.name = "F029-comparison-real"; overview.lifetime = .keepAlways; add(overview)
        app.buttons["comparison.zoom.1"].tap()
        XCTAssertTrue(app.buttons["comparison.zoom-toggle"].waitForExistence(timeout: 5)); app.buttons["comparison.zoom-toggle"].tap()
        let zoom = XCTAttachment(screenshot: app.screenshot()); zoom.name = "F029-comparison-zoom"; zoom.lifetime = .keepAlways; add(zoom)
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
    func testMaximumTextOpaqueComparisonActionsRemainReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--comparison-test-host", "--reduced-transparency-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleLanguages", "(en)"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<10 where !app.buttons["comparison.keep.1"].isHittable { scroll.swipeUp() }
        XCTAssertTrue(app.buttons["comparison.keep.1"].isHittable)
        app.buttons["comparison.keep.1"].tap()
        for _ in 0..<10 where !app.buttons["comparison.confirm"].isHittable { scroll.swipeUp() }
        XCTAssertTrue(app.buttons["comparison.confirm"].isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "F029-comparison-real-large"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["comparison.confirm"].tap()
        XCTAssertTrue(app.staticTexts["comparison.saved"].waitForExistence(timeout: 5))
        app.buttons["comparison.close"].tap()
        XCTAssertEqual(app.staticTexts["comparison.test-state"].label, "pending=1")
    }

}
