import XCTest

@MainActor final class ReviewTests: XCTestCase {
    func testImmersiveGesturesZoomButtonsAndVideoSlider() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--review-test-host", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        let state = app.staticTexts["review.test-state"]
        func expect(_ text: String) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: state)], timeout: 10), .completed, state.label)
        }
        expect("cursor=0"); XCTAssertFalse(app.buttons["review.back"].exists)
        let photo = app.descendants(matching: .any)["review.photo"]
        photo.swipeLeft(); expect("cursor=1")
        photo.swipeRight(); expect("cursor=0")
        let original = state.label.components(separatedBy: "current=").last!.components(separatedBy: " ").first!
        photo.swipeUp(); expect("intents=1"); expect("kind=pending"); expect("target=\(original)"); expect("cursor=0")
        photo.swipeDown(); expect("intents=2"); expect("kind=favorite"); expect("cursor=0")
        app.tapReviewCanvas()
        XCTAssertTrue(app.buttons["review.back"].waitForExistence(timeout: 5))
        XCTAssertLessThan(app.buttons["review.back"].frame.midY, app.frame.height * 0.25)
        XCTAssertGreaterThan(app.buttons["下一项"].frame.midY, app.frame.height * 0.7)
        XCTAssertGreaterThanOrEqual(app.buttons["下一项"].frame.height, 44)
        let glass = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); glass.name = "F009-v3-two-pills"; glass.lifetime = .keepAlways; add(glass)
        app.buttons["review.zoom"].tap()
        XCTAssertTrue((photo.value as? String)?.contains("200%") == true)
        photo.swipeLeft(); photo.swipeUp(); expect("cursor=0"); expect("intents=2")
        app.buttons["review.zoom"].tap()
        photo.pinch(withScale: 2, velocity: 1)
        photo.swipeLeft(); photo.swipeUp(); expect("cursor=0"); expect("intents=2")
        app.buttons["review.zoom"].tap()
        photo.swipeLeft(); expect("cursor=1")
        photo.swipeRight(); expect("cursor=0")
        app.buttons["review.pending"].tap(); expect("intents=3")
        app.buttons["下一项"].tap(); expect("cursor=1")
        app.buttons["下一项"].tap(); expect("cursor=2")
        XCTAssertTrue(app.sliders["video.progress"].waitForExistence(timeout: 10))
        app.sliders["video.progress"].adjust(toNormalizedSliderPosition: 0.6)
        expect("cursor=2"); expect("intents=3")
        app.tapReviewCanvas(); XCTAssertFalse(app.buttons["review.back"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "F010-immersive-video"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
