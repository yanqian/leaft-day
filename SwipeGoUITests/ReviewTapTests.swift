import XCTest

@MainActor final class ReviewTapTests: XCTestCase {
    func testEveryMediaRegionTogglesWithoutMovingOrResizing() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--home-navigation-test-host", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15)); app.buttons["home.continue"].tap()
        let back = app.buttons["review.back"]
        let points: [(CGFloat, CGFloat)] = [(0.5, 0.05), (0.5, 0.5), (0.05, 0.45), (0.95, 0.45), (0.5, 0.94)]
        func exerciseRegions(position: String) {
            for (x, y) in points {
                XCTAssertFalse(back.exists)
                app.tapReviewCanvas(x: x, y: y)
                XCTAssertTrue(back.waitForExistence(timeout: 5))
                XCTAssertEqual(app.staticTexts["review.position"].label, position)
                app.tapReviewCanvas(x: 0.5, y: 0.35)
                XCTAssertFalse(back.exists)
            }
        }
        exerciseRegions(position: "本轮剩余 3 项")
        app.descendants(matching: .any)["review.photo"].swipeLeft()
        let video = app.descendants(matching: .any)["video.surface"]
        XCTAssertTrue(video.waitForExistence(timeout: 10))
        let hiddenFrame = video.frame
        exerciseRegions(position: "本轮剩余 2 项")
        app.tapReviewCanvas()
        XCTAssertEqual(video.frame, hiddenFrame, "Controls must overlay, not shrink the media")
        XCTAssertTrue(app.buttons["video.playback"].waitForExistence(timeout: 10))
        app.buttons["video.playback"].tap(); XCTAssertTrue(back.exists)
        app.buttons["video.mute"].tap(); XCTAssertTrue(back.exists)
        app.sliders["video.progress"].adjust(toNormalizedSliderPosition: 0.4)
        XCTAssertTrue(back.exists); XCTAssertEqual(app.staticTexts["review.position"].label, "本轮剩余 2 项")
        let play = app.buttons["video.playback"]
        if play.label == "暂停" { play.tap() }
        app.sliders["video.progress"].adjust(toNormalizedSliderPosition: 0)
        app.tapReviewCanvas(); app.tapReviewCanvas()
        XCTAssertEqual(play.label, "播放", "Media tap must not start paused playback")
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "F019-video-overlay"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
