import XCTest

@MainActor
final class LaunchTests: XCTestCase {
    private func assertRoot(_ app: XCUIApplication) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons["home.settings"].exists || app.staticTexts["LeafDay"].exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed)
    }
    private func visibleIcon(in springboard: XCUIApplication) -> XCUIElement? {
        springboard.icons.matching(identifier: "LeafDay").allElementsBoundByIndex.first {
            $0.exists && $0.isHittable && springboard.frame.contains($0.frame)
        }
    }
    private func captureDesktop(_ springboard: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: springboard.debugDescription)
        tree.name = name + "-hierarchy"; tree.lifetime = .keepAlways; add(tree)
    }
    func testColdLaunchAndRelaunchShowRoot() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        assertRoot(app)
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 5))
        // Return from App Library/folders to the first page before scanning.
        XCUIDevice.shared.press(.home)
        for _ in 0..<5 {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.visibleIcon(in: springboard) != nil
            }, object: nil)
            if XCTWaiter.wait(for: [ready], timeout: 2) == .completed { break }
            springboard.swipeLeft()
        }
        captureDesktop(springboard, name: "F030-LeafDay-home-screen")
        let icon = try XCTUnwrap(visibleIcon(in: springboard), "LeafDay must have a visible, tappable system icon")
        icon.tap()
        assertRoot(app)
        app.terminate()
        app.launch()
        assertRoot(app)
    }
}
