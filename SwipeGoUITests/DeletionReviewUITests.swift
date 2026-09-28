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
        XCTAssertFalse(app.buttons["deletion.prepare"].isEnabled)
        app.buttons["播放视频确认"].tap()
        XCTAssertTrue(app.sliders["video.progress"].waitForExistence(timeout: 10))
        app.buttons["deletion.video-close"].tap()
        app.buttons["deletion.retract.2"].tap()
        XCTAssertTrue(app.buttons["deletion.prepare"].isEnabled)
        app.buttons["deletion.prepare"].tap()
        XCTAssertTrue(app.staticTexts["deletion.frozen-count"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["deletion.frozen-count"].label, "本次共 2 项")
        let confirmImage = XCTAttachment(screenshot: app.screenshot()); confirmImage.name = "F015-fixed-confirmation"; confirmImage.lifetime = .keepAlways; add(confirmImage)
        XCTAssertFalse(app.buttons["deletion.execute"].isEnabled, "F016 not connected yet")
        app.buttons["deletion.cancel"].tap()
        app.buttons["deletion.close"].tap()
        XCTAssertTrue(app.buttons["home.pending"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.pending"].label, "待删 2 项")
        app.buttons["home.pending"].tap(); app.buttons["deletion.retract.0"].tap()
        app.buttons["deletion.close"].tap()
        XCTAssertEqual(app.buttons["home.pending"].label, "待删 1 项")
    }
}
