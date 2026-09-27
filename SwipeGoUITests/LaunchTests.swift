import XCTest

@MainActor
final class LaunchTests: XCTestCase {
    private func assertRoot(_ app: XCUIApplication) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons["home.settings"].exists || app.staticTexts["时光"].exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed)
    }
    func testColdLaunchAndRelaunchShowRoot() {
        let app = XCUIApplication()
        app.launch()
        assertRoot(app)
        app.terminate()
        app.launch()
        assertRoot(app)
    }
}
