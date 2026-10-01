import XCTest

@MainActor final class HomeNavigationTests: XCTestCase {
    func testContinueSwipesPhotosVideoBlackBarsAndBoundaries() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--home-navigation-test-host", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15)); app.buttons["home.continue"].tap()
        let photo = app.descendants(matching: .any)["review.photo"]
        let video = app.descendants(matching: .any)["video.surface"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["review.back"].exists)
        photo.swipeLeft(); XCTAssertTrue(video.waitForExistence(timeout: 10))
        app.tapReviewCanvas()
        let position = app.staticTexts["review.position"]
        func expect(_ value: String) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: position)], timeout: 10), .completed)
        }
        expect("本轮剩余 2 项")
        video.swipeRight(); expect("本轮剩余 3 项")
        photo.swipeRight()
        XCTAssertTrue(app.staticTexts["已经是这一段的第一项"].waitForExistence(timeout: 3)); expect("本轮剩余 3 项")
        // Landscape fixture fits in the middle; this y lies in its upper black bar,
        // below the legacy top trigger area and above the bottom toolbar.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: photo.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)))
        expect("本轮剩余 2 项")
        video.swipeLeft(); expect("本轮剩余 1 项")
        photo.swipeLeft()
        XCTAssertTrue(app.staticTexts["已经是这一段的最后一项"].waitForExistence(timeout: 3)); expect("本轮剩余 1 项")
        photo.swipeRight(); expect("本轮剩余 2 项")
        app.sliders["video.progress"].adjust(toNormalizedSliderPosition: 0.6); expect("本轮剩余 2 项")
        app.buttons["review.back"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10)); app.buttons["home.continue"].tap()
        app.tapReviewCanvas(); expect("本轮剩余 2 项")
    }
}
