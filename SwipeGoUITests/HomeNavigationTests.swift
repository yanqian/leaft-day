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
        expect("剩余 1 项")
        video.swipeRight(); expect("剩余 2 项")
        photo.swipeRight()
        XCTAssertTrue(app.staticTexts["已经是这一段的第一项"].waitForExistence(timeout: 3)); expect("剩余 2 项")
        // Landscape fixture fits in the middle; this y lies in its upper black bar,
        // below the legacy top trigger area and above the bottom toolbar.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: photo.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)))
        expect("剩余 1 项")
        video.swipeLeft(); expect("剩余 0 项")
        XCTAssertFalse(app.buttons["下一项"].isEnabled)
        let last = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); last.name = "F032-last-item-zero"; last.lifetime = .keepAlways; add(last)
        photo.swipeLeft()
        XCTAssertTrue(app.staticTexts["已经是这一段的最后一项"].waitForExistence(timeout: 3)); expect("剩余 0 项")
        photo.swipeRight(); expect("剩余 1 项")
        app.sliders["video.progress"].adjust(toNormalizedSliderPosition: 0.6); expect("剩余 1 项")
        app.buttons["review.back"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10)); app.buttons["home.continue"].tap()
        app.tapReviewCanvas(); expect("剩余 1 项")
    }
    func testRandomPreviewOpensSameMemoryAndChangesOnlyAfterRandomVisit() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--home-navigation-test-host", "--random-preview-test", "-AppleLanguages", "(en)"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        let random = app.buttons["home.random"]
        XCTAssertTrue(random.waitForExistence(timeout: 15))
        func preview() -> String {
            let value = random.value as? String ?? ""
            let parts = value.components(separatedBy: ";covers=")
            XCTAssertEqual(parts.count, 2)
            let ids = parts[0].components(separatedBy: ",")
            let covers = parts[1].components(separatedBy: ",")
            XCTAssertEqual(ids.count, 2)
            XCTAssertFalse(covers.contains(""))
            XCTAssertTrue(Set(covers).isSubset(of: Set(ids)))
            return parts[0]
        }
        let first = preview()
        let cover = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); cover.name = "F034-random-preview"; cover.lifetime = .keepAlways; add(cover)
        // Continuing another session must not consume the random preview.
        app.buttons["home.continue"].tap(); app.tapReviewCanvas(); app.buttons["review.back"].tap()
        XCTAssertTrue(random.waitForExistence(timeout: 10))
        XCTAssertEqual(preview(), first)
        random.tap(); app.tapReviewCanvas()
        XCTAssertEqual(app.staticTexts["review.position"].value as? String, first)
        let opened = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); opened.name = "F034-random-opened"; opened.lifetime = .keepAlways; add(opened)
        app.buttons["review.back"].tap()
        XCTAssertTrue(random.waitForExistence(timeout: 10))
        let changed = NSPredicate { _, _ in
            !(random.value as? String ?? "").hasPrefix(first + ";covers=")
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: nil)], timeout: 10), .completed)
        let second = preview()
        XCTAssertNotEqual(second, first)
        random.tap(); app.tapReviewCanvas()
        XCTAssertEqual(app.staticTexts["review.position"].value as? String, second)
    }

}
