import XCTest

@MainActor final class FavoriteUITests: XCTestCase {
    func testFavoriteRepeatAndUndoAfterPagingTargetsOriginal() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--favorite-test-host", "-AppleLanguages", "(en)"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        let state = app.staticTexts["review.test-state"]
        func expect(_ text: String) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: state)], timeout: 10), .completed, state.label)
        }
        expect("firstFavorite=false")
        app.descendants(matching: .any)["review.photo"].swipeDown()
        expect("firstFavorite=true"); expect("cursor=0")
        app.tapReviewCanvas()
        XCTAssertTrue(app.buttons["review.favorite"].waitForExistence(timeout: 5))
        app.buttons["review.favorite"].tap()
        expect("firstFavorite=true")
        app.buttons["下一项"].tap(); expect("cursor=1")
        app.buttons["review.undo"].tap()
        expect("firstFavorite=false"); expect("cursor=1")
        XCTAssertFalse(app.buttons["review.undo"].isEnabled)
    }
}
