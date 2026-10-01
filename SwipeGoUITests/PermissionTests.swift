import XCTest

@MainActor
final class PermissionTests: XCTestCase {
    private func request() -> (XCUIApplication, XCUIApplication) {
        let app = XCUIApplication()
        app.terminate()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["permission.request"].waitForExistence(timeout: 10))
        app.buttons["permission.request"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.alerts.firstMatch.waitForExistence(timeout: 10))
        // Native photo thumbnails resize the authorization sheet on compact
        // devices. Wait for its actual button frame to settle before tapping.
        let deny = system.buttons["Don’t Allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 10))
        var previous = CGRect.null
        var changedAt = Date()
        let settled = NSPredicate { _, _ in
            guard deny.exists, deny.isHittable else { return false }
            let frame = deny.frame
            if frame != previous { previous = frame; changedAt = Date(); return false }
            return Date().timeIntervalSince(changedAt) >= 0.6
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 10), .completed)
        return (app, system)
    }

    private func openSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 10))
        app.buttons["home.settings"].tap()
    }

    func testDeniedGuidance() {
        let (app, system) = request()
        system.buttons["Don’t Allow"].tap()
        let ready = app.buttons["打开设置"].waitForExistence(timeout: 10)
        if !ready { let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screen.name = "permission-denial-system-state"; screen.lifetime = .keepAlways; add(screen) }
        XCTAssertTrue(ready)
        XCTAssertFalse(app.staticTexts["library.count"].exists)
    }

    func testFullAccessQueriesRealLibrary() {
        let (app, system) = request()
        system.buttons["Allow Full Access"].tap()
        openSettings(app)
        XCTAssertTrue(app.staticTexts["library.count"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["管理所选照片"].exists)
        print("REAL_FULL_QUERY: \(app.staticTexts["library.count"].label)")
    }

    func testLimitedEmptyRangeIsNotReportedAsEmptyWholeLibrary() {
        let (app, system) = request()
        system.buttons["Limit Access…"].tap()
        XCTAssertTrue(app.buttons["Update"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.images.matching(identifier: "PXGGridLayout-Info").firstMatch.waitForExistence(timeout: 15))
        app.buttons["Update"].tap()
        XCTAssertTrue(app.buttons["Update"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.anniversary"].waitForExistence(timeout: 10))
        if !app.buttons["home.anniversary"].isHittable { app.swipeUp() }
        app.buttons["home.anniversary"].tap()
        XCTAssertTrue(app.alerts["回顾提示"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["这段时光暂无可回顾内容。"].exists)
        app.alerts.buttons["好"].tap()
        app.swipeDown()
        openSettings(app)
        expectation(for: NSPredicate(format: "label == %@", "所选范围内暂无可回顾内容。"), evaluatedWith: app.staticTexts["library.count"])
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["管理所选照片"].exists)
    }

    func testLimitedSelectionAndScopeUpdate() {
        let (app, system) = request()
        system.buttons["Limit Access…"].tap()
        let items = app.images.matching(identifier: "PXGGridLayout-Info")
        XCTAssertTrue(items.firstMatch.waitForExistence(timeout: 15))
        items.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        items.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Update"].tap()
        XCTAssertTrue(app.buttons["Update"].waitForNonExistence(timeout: 10))
        openSettings(app)
        let count = app.staticTexts["library.count"]
        let two = NSPredicate(format: "label == %@", "可回顾 2 项")
        expectation(for: two, evaluatedWith: count)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["管理所选照片"].exists)
        app.buttons["管理所选照片"].tap()
        XCTAssertTrue(items.firstMatch.waitForExistence(timeout: 15))
        items.element(boundBy: 2).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Update"].tap()
        XCTAssertTrue(app.buttons["Update"].waitForNonExistence(timeout: 10))
        expectation(for: NSPredicate(format: "label == %@", "可回顾 3 项"), evaluatedWith: count)
        waitForExpectations(timeout: 10)
    }
}
