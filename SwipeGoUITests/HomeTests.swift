import XCTest

@MainActor final class HomeTests: XCTestCase {
    private func showReviewControls(_ app: XCUIApplication) {
        app.tapReviewCanvas()
        XCTAssertTrue(app.buttons["review.back"].waitForExistence(timeout: 10))
    }
    func testRealHomeRandomAndPersistedContinue() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.terminate()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["permission.request"].waitForExistence(timeout: 10))
        app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "日叶")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["顺手整理"].exists)
        let pending = app.buttons["home.pending"]
        XCTAssertTrue(pending.isHittable)
        XCTAssertFalse(app.staticTexts["home.scope"].exists, "No whole-library count below pending")
        for id in ["home.anniversary", "home.random"] {
            let card = app.buttons[id]
            XCTAssertGreaterThanOrEqual(card.frame.height, app.frame.height * 0.25, "Photo cards retain the approved tall proportions")
            XCTAssertGreaterThan(pending.frame.minY, card.frame.maxY, "Pending is the final card")
        }
        XCTAssertGreaterThan(pending.frame.width, app.frame.width * 0.75)
        XCTAssertLessThan(pending.frame.maxY, app.frame.maxY - 24, "Pending card must fit above home indicator without scrolling")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
        let home = XCTAttachment(screenshot: app.screenshot()); home.name = "F009-home-real-library"; home.lifetime = .keepAlways; add(home)
        if !app.buttons["home.random"].isHittable { app.swipeUp() }
        app.buttons["home.random"].tap()
        showReviewControls(app)
        let review = XCTAttachment(screenshot: app.screenshot()); review.name = "F010-real-bottom-controls"; review.lifetime = .keepAlways; add(review)
        app.buttons["review.back"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home.continue"].label.contains("继续回顾"))
        app.buttons["home.continue"].tap()
        showReviewControls(app)
    }
    func testReducedTransparencyUsesReadableControls() throws {
        let app = XCUIApplication()
        app.terminate()
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
        XCTAssertTrue(app.buttons["完成"].isHittable)
        let settings = XCTAttachment(screenshot: app.screenshot()); settings.name = "F022-settings-opaque"; settings.lifetime = .keepAlways; add(settings)
    }
    func testLargeTextHomeRemainsNavigable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.terminate()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["permission.request"].waitForExistence(timeout: 10)); app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 15))
        let top = XCTAttachment(screenshot: app.screenshot()); top.name = "F009-home-large-top"; top.lifetime = .keepAlways; add(top)
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["完成"].isHittable)
        app.swipeUp()
        XCTAssertTrue(app.buttons["settings.explanation"].isHittable)
        app.buttons["settings.explanation"].tap()
        XCTAssertTrue(app.staticTexts["settings.details"].exists)
        let scroll = app.scrollViews["settings.scroll"]
        XCTAssertLessThanOrEqual(scroll.frame.maxY, app.buttons["完成"].frame.minY)
        scroll.swipeUp()
        XCTAssertTrue(app.staticTexts["仅支持个人图库"].isHittable)
        XCTAssertLessThanOrEqual(app.staticTexts["仅支持个人图库"].frame.maxY, scroll.frame.maxY)
        let settings = XCTAttachment(screenshot: app.screenshot()); settings.name = "F022-settings-large"; settings.lifetime = .keepAlways; add(settings)
        app.buttons["完成"].tap()
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(app.buttons["home.random"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "F009-home-large-text"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["home.random"].tap()
        showReviewControls(app)
    }
}
