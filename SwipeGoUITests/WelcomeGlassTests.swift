import XCTest

@MainActor final class WelcomeGlassTests: XCTestCase {
    private func open(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.terminate(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["-AppleLanguages", "(en)"] + arguments
        app.launch(); XCTAssertTrue(app.buttons["permission.request"].waitForExistence(timeout: 10)); return app
    }
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testWelcomeGlassBeforeNativePermission() throws {
        continueAfterFailure = false
        let app = open()
        XCTAssertTrue(app.staticTexts["只在你授权的范围内浏览"].exists)
        XCTAssertFalse(app.staticTexts["library.count"].exists)
        XCTAssertTrue(app.buttons["permission.request"].isHittable)
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
        attach("F025-welcome-glass")
        app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Don’t Allow"].waitForExistence(timeout: 10)); system.buttons["Don’t Allow"].tap()
        XCTAssertTrue(app.buttons["打开设置"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["permission.request"].exists)
        attach("F025-welcome-denied")
    }
    func testWelcomeLargeOpaqueCanRequest() throws {
        continueAfterFailure = false
        let app = open(["--reduced-transparency-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["permission.request"].isHittable)
        let scroll = app.scrollViews["welcome.scroll"]
        XCTAssertLessThanOrEqual(scroll.frame.maxY, app.buttons["permission.request"].frame.minY)
        scroll.swipeUp()
        XCTAssertTrue(app.staticTexts["permission.guidance"].isHittable)
        let lastGuidance = app.staticTexts["只在你授权的范围内浏览"]
        XCTAssertTrue(lastGuidance.isHittable)
        XCTAssertLessThanOrEqual(lastGuidance.frame.maxY, scroll.frame.maxY)
        XCTAssertLessThanOrEqual(lastGuidance.frame.maxY, app.buttons["permission.request"].frame.minY)
        attach("F025-welcome-large-opaque")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
        app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 15))
    }
}
