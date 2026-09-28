import XCTest

@MainActor final class DeletionUITests: XCTestCase {
    func testNativeBatchCancelThenSuccessOnNewDisposablePhotos() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--deletion-test-host", "-AppleLanguages", "(en)"]; app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["deletion.prepare"].waitForExistence(timeout: 15))
        func submit() {
            app.buttons["deletion.prepare"].tap()
            XCTAssertTrue(app.switches["deletion.personal-library"].waitForExistence(timeout: 5))
            app.swipeUp()
            app.switches["deletion.personal-library"].tap()
            app.buttons["deletion.execute"].tap()
        }
        submit()
        XCTAssertTrue(system.alerts.firstMatch.waitForExistence(timeout: 10))
        system.alerts.buttons["Don’t Allow"].tap()
        XCTAssertTrue(app.staticTexts["deletion.result"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["deletion.result"].label.contains("取消"))
        app.buttons["deletion.cancel"].tap(); app.buttons["deletion.test-check"].tap()
        XCTAssertTrue(app.staticTexts["deletion.test-state"].label.contains("targets=2 keeper=1 pending=2 success=0 cancelled=1"))
        submit()
        XCTAssertTrue(system.alerts.firstMatch.waitForExistence(timeout: 10))
        let screen = XCTAttachment(screenshot: system.screenshot()); screen.name = "F016-native-delete-confirmation"; screen.lifetime = .keepAlways; add(screen)
        system.alerts.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["deletion.result"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["deletion.result"].label.contains("系统已确认删除本次清单"))
        XCTAssertFalse(app.buttons["deletion.execute"].isEnabled)
        app.buttons["deletion.cancel"].tap(); app.buttons["deletion.test-check"].tap()
        XCTAssertTrue(app.staticTexts["deletion.test-state"].label.contains("targets=0 keeper=1 pending=0 success=1 cancelled=1"))
    }
}
