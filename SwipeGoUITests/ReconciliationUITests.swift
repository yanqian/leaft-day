import XCTest

@MainActor final class ReconciliationUITests: XCTestCase {
    func testInterruptedOperationSurvivesRelaunchAndAcknowledgementPreservesPending() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--reconciliation-test-host", "--reconciliation-store=" + UUID().uuidString, "-AppleLanguages", "(en)"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.reconciliation"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.reconciliation"].waitForExistence(timeout: 10))
        app.buttons["home.reconciliation"].tap()
        XCTAssertTrue(app.staticTexts["删除结果待核对"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["本次 1 项 · 当前可访问 1 项"].exists)
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "F017-reconciliation"; image.lifetime = .keepAlways; add(image)
        app.buttons["reconciliation.acknowledge"].tap()
        XCTAssertTrue(app.staticTexts["reconciliation.empty"].waitForExistence(timeout: 10))
        app.buttons["reconciliation.close"].tap()
        XCTAssertTrue(app.buttons["home.pending"].label.contains("待删 2 项"))
        XCTAssertTrue(app.buttons["home.pending"].label.contains("待核对 1 项"))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.pending"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["home.reconciliation"].exists)
        XCTAssertTrue(app.buttons["home.pending"].label.contains("待删 2 项"))
    }
}
