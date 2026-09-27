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
        return (app, system)
    }

    func testDeniedGuidance() {
        let (app, system) = request()
        system.buttons["Don’t Allow"].tap()
        XCTAssertTrue(app.buttons["打开设置"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["library.count"].exists)
    }

    func testFullAccessQueriesRealLibrary() {
        let (app, system) = request()
        system.buttons["Allow Full Access"].tap()
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
