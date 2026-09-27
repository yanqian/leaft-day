import XCTest

@MainActor final class HomeTests: XCTestCase {
    func testRealHomeRandomAndPersistedContinue() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["permission.request"].waitForExistence(timeout: 10))
        app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["顺手整理"].exists)
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
        let home = XCTAttachment(screenshot: app.screenshot()); home.name = "F009-home-real-library"; home.lifetime = .keepAlways; add(home)
        if !app.buttons["home.random"].isHittable { app.swipeUp() }
        app.buttons["home.random"].tap()
        XCTAssertTrue(app.buttons["review.back"].waitForExistence(timeout: 15))
        app.buttons["review.back"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home.continue"].label.contains("继续回顾"))
        app.buttons["home.continue"].tap()
        XCTAssertTrue(app.buttons["review.back"].waitForExistence(timeout: 15))
    }
    func testReducedTransparencyUsesReadableControls() throws {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--reduced-transparency-test", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["permission.request"].waitForExistence(timeout: 10)); app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "F009-home-reduced-transparency"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["home.settings"].tap(); XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 10))
    }
    func testLargeTextHomeRemainsNavigable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["permission.request"].waitForExistence(timeout: 10)); app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 15))
        let top = XCTAttachment(screenshot: app.screenshot()); top.name = "F009-home-large-top"; top.lifetime = .keepAlways; add(top)
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 10)); app.buttons["完成"].tap()
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(app.buttons["home.random"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "F009-home-large-text"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["home.random"].tap()
        XCTAssertTrue(app.buttons["review.back"].waitForExistence(timeout: 15))
    }
}
