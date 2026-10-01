import XCTest

@MainActor final class ReviewContinuityUITests: XCTestCase {
    func testHomeContinueRandomAndOneItemAnniversaryExpansion() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--continuity-test-host", "-AppleLanguages", "(en)"]; app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15))
        let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); home.name = "F009-v5-home-photo-cards"; home.lifetime = .keepAlways; add(home)
        app.buttons["home.continue"].tap()
        app.tapReviewCanvas()
        let position = app.staticTexts["review.position"]
        func expect(_ label: String) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: position)], timeout: 10), .completed)
        }
        expect("本轮剩余 3 项")
        app.descendants(matching: .any)["review.photo"].swipeLeft(); expect("本轮剩余 2 项")
        app.buttons["review.back"].tap(); app.buttons["home.continue"].tap(); app.tapReviewCanvas(); expect("本轮剩余 2 项")
        app.buttons["review.back"].tap(); app.buttons["home.random"].tap(); app.tapReviewCanvas(); expect("本轮剩余 3 项")
        app.buttons["下一项"].tap(); expect("本轮剩余 2 项")
        app.buttons["review.back"].tap(); app.buttons["home.anniversary"].tap(); app.tapReviewCanvas(); expect("本轮剩余 1 项")
        XCTAssertFalse(app.buttons["下一项"].isEnabled)
        XCTAssertTrue(app.buttons["review.nearby"].isHittable)
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); before.name = "F021-anniversary-single"; before.lifetime = .keepAlways; add(before)
        app.buttons["review.nearby"].tap(); expect("本轮剩余 2 项")
        app.buttons["下一项"].tap(); expect("本轮剩余 1 项")
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); after.name = "F021-nearby-expanded"; after.lifetime = .keepAlways; add(after)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)], timeout: 10), .completed)
        expect("本轮剩余 1 项")
        let slider = app.sliders["video.progress"]
        XCTAssertTrue(slider.isHittable); XCTAssertTrue(app.frame.contains(slider.frame))
        XCTAssertTrue(app.buttons["review.nearby"].isHittable)
        XCTAssertLessThan(slider.frame.maxY, app.buttons["review.nearby"].frame.minY)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); landscape.name = "F021-terminal-landscape"; landscape.lifetime = .keepAlways; add(landscape)
    }
}
