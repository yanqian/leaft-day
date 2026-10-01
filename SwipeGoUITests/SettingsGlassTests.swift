import XCTest

@MainActor final class SettingsGlassTests: XCTestCase {
    func testRealSettingsDisclosureAndDismissal() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.terminate()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["permission.request"].waitForExistence(timeout: 10)); app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 15)); app.buttons["home.settings"].tap()
        XCTAssertTrue(app.staticTexts["library.count"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["settings.details"].exists)
        let collapsed = XCTAttachment(screenshot: app.screenshot()); collapsed.name = "F022-settings-glass"; collapsed.lifetime = .keepAlways; add(collapsed)
        app.buttons["settings.explanation"].tap()
        XCTAssertTrue(app.staticTexts["settings.details"].exists)
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
        let expanded = XCTAttachment(screenshot: app.screenshot()); expanded.name = "F022-settings-expanded"; expanded.lifetime = .keepAlways; add(expanded)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 10))
    }
}
