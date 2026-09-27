import XCTest

@MainActor final class PendingUITests: XCTestCase {
    func testMarkRepeatRestartFavoritePromptAndUndoOriginal() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--pending-test-host", "-AppleLanguages", "(en)"]; app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        let state = app.staticTexts["review.test-state"]
        func expect(_ text: String) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: state)], timeout: 10), .completed, state.label)
        }
        expect("pending=0")
        app.descendants(matching: .any)["review.photo"].swipeUp(); expect("pending=1"); expect("cursor=0")
        app.descendants(matching: .any)["review.photo"].swipeUp(); expect("pending=1")
        app.terminate(); app.launchArguments.append("--preserve-review-store"); app.launch()
        expect("pending=1"); expect("firstPending=true")
        // A repeated durable mark is not a fresh action to undo.
        app.buttons["review.toggle"].tap()
        XCTAssertFalse(app.buttons["review.undo"].isEnabled)
        app.buttons["下一项"].tap(); expect("cursor=1")
        app.buttons["review.favorite"].tap()
        XCTAssertTrue(app.staticTexts["review.feedback"].waitForExistence(timeout: 5))
        app.buttons["review.pending"].tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 5)); app.buttons["取消"].tap(); expect("pending=1")
        app.buttons["review.pending"].tap()
        XCTAssertTrue(app.buttons["仍加入待删"].waitForExistence(timeout: 5)); app.buttons["仍加入待删"].tap(); expect("pending=2")
        XCTAssertEqual(app.buttons["review.favorite"].label, "已收藏")
        app.buttons["上一项"].tap(); expect("cursor=0")
        app.buttons["review.undo"].tap(); expect("pending=1"); expect("firstPending=true"); expect("cursor=0")
    }
}
