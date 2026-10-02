import XCTest

@MainActor final class ReviewOrientationTests: XCTestCase {
    private func openReview(accessibility: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--home-navigation-test-host", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if accessibility { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15)); app.buttons["home.continue"].tap()
        app.tapReviewCanvas()
        return app
    }
    private func expectOrientation(_ app: XCUIApplication, landscape: Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            landscape ? app.frame.width > app.frame.height : app.frame.height > app.frame.width
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func testPhotoAndVideoBothLandscapesPreservePositionAndReturnHomePortrait() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = openReview()
        let position = app.staticTexts["review.position"]
        let photo = app.descendants(matching: .any)["review.photo"]
        XCTAssertEqual(position.label, "剩余 2 项")
        app.buttons["review.zoom"].tap()
        for direction in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = direction; expectOrientation(app, landscape: true)
            XCTAssertEqual(position.label, "剩余 2 项")
            XCTAssertTrue((photo.value as? String)?.contains("100%") == true)
            for id in ["review.back", "review.zoom", "review.favorite", "review.pending", "review.similar", "review.undo"] {
                let button = app.buttons[id]
                XCTAssertTrue(button.exists); XCTAssertTrue(app.frame.contains(button.frame), id)
            }
            XCTAssertTrue(app.buttons["下一项"].isHittable)
            app.buttons["review.zoom"].tap()
            XCTAssertTrue((photo.value as? String)?.contains("200%") == true)
            app.buttons["review.zoom"].tap()
            XCTAssertTrue((photo.value as? String)?.contains("100%") == true)
            app.tapReviewCanvas(x: 0.5, y: 0.15)
            XCTAssertFalse(app.buttons["review.back"].exists)
            app.tapReviewCanvas(x: 0.5, y: 0.15)
            XCTAssertTrue(app.buttons["review.back"].exists)
            attach(app, "F020-photo-\(direction.rawValue)")
        }
        XCUIDevice.shared.orientation = .portrait; expectOrientation(app, landscape: false)
        XCTAssertEqual(position.label, "剩余 2 项")
        app.buttons["下一项"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["video.surface"].waitForExistence(timeout: 10))
        if app.buttons["video.playback"].label == "暂停" { app.buttons["video.playback"].tap() }
        for direction in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = direction; expectOrientation(app, landscape: true)
            XCTAssertEqual(position.label, "剩余 1 项")
            XCTAssertTrue(app.buttons["video.playback"].isHittable)
            XCTAssertTrue(app.buttons["video.mute"].isHittable)
            XCTAssertTrue(app.sliders["video.progress"].isHittable)
            XCTAssertTrue(app.frame.contains(app.sliders["video.progress"].frame))
            app.sliders["video.progress"].adjust(toNormalizedSliderPosition: 0.4)
            XCTAssertEqual(position.label, "剩余 1 项")
            XCTAssertEqual(app.buttons["video.playback"].label, "播放")
            attach(app, "F020-video-\(direction.rawValue)")
        }
        app.buttons["review.back"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10)); expectOrientation(app, landscape: false)
        attach(app, "F020-home-restored")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["home.continue"].tap(); app.tapReviewCanvas()
        XCTAssertEqual(position.label, "剩余 1 项")
    }
    func testAccessibilityLandscapeControlsRemainReachable() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = openReview(accessibility: true)
        XCUIDevice.shared.orientation = .landscapeLeft; expectOrientation(app, landscape: true)
        XCTAssertTrue(app.buttons["review.back"].isHittable)
        let scroll = app.scrollViews.firstMatch
        scroll.swipeUp()
        XCTAssertTrue(app.buttons["review.pending"].isHittable)
        XCTAssertTrue(app.frame.contains(app.buttons["review.pending"].frame))
        attach(app, "F020-accessibility-landscape")
        scroll.swipeDown()
        app.buttons["review.back"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10)); expectOrientation(app, landscape: false)
    }
}
