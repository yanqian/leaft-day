import XCTest

@MainActor final class DeletionReviewUITests: XCTestCase {
    func testHomeCountsGroupedReviewVideoRetractionAndFrozenCancel() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--deletion-review-test-host", "-AppleLanguages", "(en)"]; app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.pending"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.pending"].label.contains("待删 2 项")); XCTAssertTrue(app.buttons["home.pending"].label.contains("待核对 1 项"))
        app.buttons["home.pending"].tap()
        XCTAssertTrue(app.staticTexts["deletion.keepers"].waitForExistence(timeout: 10))
        let reviewImage = XCTAttachment(screenshot: app.screenshot()); reviewImage.name = "F015-deletion-review"; reviewImage.lifetime = .keepAlways; add(reviewImage)
        XCTAssertLessThanOrEqual(app.scrollViews["deletion.review-scroll"].frame.maxY, app.buttons["deletion.prepare"].frame.minY)
        XCTAssertFalse(app.buttons["deletion.prepare"].isEnabled)
        for _ in 0..<4 where !app.buttons["播放视频确认"].isHittable { app.scrollViews["deletion.review-scroll"].swipeUp() }
        app.buttons["播放视频确认"].tap()
        XCTAssertTrue(app.sliders["video.progress"].waitForExistence(timeout: 10))
        app.buttons["deletion.video-close"].tap()
        for _ in 0..<4 where !app.buttons["deletion.retract.2"].isHittable { app.scrollViews["deletion.review-scroll"].swipeUp() }
        app.buttons["deletion.retract.2"].tap()
        XCTAssertTrue(app.buttons["deletion.prepare"].isEnabled)
        app.buttons["deletion.prepare"].tap()
        XCTAssertTrue(app.staticTexts["deletion.frozen-count"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["deletion.frozen-count"].label, "本次共 2 项")
        let confirmImage = XCTAttachment(screenshot: app.screenshot()); confirmImage.name = "F015-fixed-confirmation"; confirmImage.lifetime = .keepAlways; add(confirmImage)
        XCTAssertLessThanOrEqual(app.scrollViews["deletion.confirm-scroll"].frame.maxY, app.buttons["deletion.execute"].frame.minY)
        XCTAssertFalse(app.buttons["deletion.execute"].isEnabled, "Explicit personal-library confirmation is required")
        app.buttons["deletion.cancel"].tap()
        app.buttons["deletion.close"].tap()
        XCTAssertTrue(app.buttons["home.pending"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.pending"].label, "待删 2 项")
        app.buttons["home.pending"].tap()
        XCTAssertTrue(app.buttons["deletion.retract.0"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.buttons["deletion.retract.0"].isHittable { app.scrollViews["deletion.review-scroll"].swipeDown() }
        app.buttons["deletion.retract.0"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "复核这 1 项"), object: app.buttons["deletion.prepare"])], timeout: 5), .completed)
        app.buttons["deletion.close"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "待删 1 项"), object: app.buttons["home.pending"])], timeout: 5), .completed)
    }
    func testMaximumTextConfirmationSeparatesActionsFromGuidance() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--deletion-test-host", "--reduced-transparency-test", "-AppleLanguages", "(en)", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["deletion.prepare"].waitForExistence(timeout: 15)); app.buttons["deletion.prepare"].tap()
        let scroll = app.scrollViews["deletion.confirm-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(scroll.frame.maxY, app.buttons["deletion.execute"].frame.minY)
        XCTAssertTrue(app.buttons["deletion.cancel"].isHittable)
        let consent = app.switches["deletion.personal-library"]
        for _ in 0..<10 {
            if consent.isHittable && consent.frame.maxY <= scroll.frame.maxY { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(consent.isHittable)
        XCTAssertLessThanOrEqual(consent.frame.maxY, scroll.frame.maxY)
        XCTAssertGreaterThanOrEqual(consent.frame.minY, scroll.frame.minY)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "F015-confirm-large-opaque"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertFalse(app.buttons["deletion.execute"].isEnabled)
        app.buttons["deletion.cancel"].tap()
    }

    func testFirstUseExplanationCanBeCollapsedAndReopened() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--deletion-review-test-host", "--deletion-explanation-unseen", "-AppleLanguages", "(en)"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.pending"].waitForExistence(timeout: 15)); app.buttons["home.pending"].tap()
        let acknowledgement = app.buttons["deletion.info.acknowledge"]
        XCTAssertTrue(acknowledgement.waitForExistence(timeout: 5))
        for _ in 0..<3 where !acknowledgement.isHittable { app.swipeUp() }
        acknowledgement.tap()
        XCTAssertFalse(acknowledgement.exists)
        app.buttons["deletion.close"].tap(); app.buttons["home.pending"].tap()
        XCTAssertTrue(app.buttons["deletion.prepare"].waitForExistence(timeout: 5))
        XCTAssertFalse(acknowledgement.exists)
        let info = app.buttons["deletion.info"]
        for _ in 0..<3 where !info.isHittable { app.swipeUp() }
        info.tap(); XCTAssertTrue(acknowledgement.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "F015-v3-glass-explanation"; shot.lifetime = .keepAlways; add(shot)
    }

}
