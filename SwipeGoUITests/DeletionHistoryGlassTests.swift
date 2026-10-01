import XCTest

@MainActor final class DeletionHistoryGlassTests: XCTestCase {
    private func open(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.terminate()
        app.launchArguments = ["--history-test-host", "-AppleLanguages", "(zh-Hans)"] + arguments
        app.launch(); XCTAssertTrue(app.buttons["deletion.history.close"].waitForExistence(timeout: 10)); return app
    }
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testHistoryStatesGlassAndDismissal() throws {
        continueAfterFailure = false
        let app = open()
        for text in ["2 项 · 系统已确认删除", "3 项 · 已取消", "4 项 · 未提交删除", "5 项 · 结果待核对"] {
            XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5))
        }
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
        attach("F024-history-glass")
        app.buttons["deletion.history.close"].tap()
        XCTAssertTrue(app.buttons["打开记录"].waitForExistence(timeout: 5))
    }
    func testHistoryEmptyAndFailedReadRetry() {
        continueAfterFailure = false
        let app = open(["--history-empty", "--history-read-error"])
        XCTAssertTrue(app.buttons["history.retry"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["没有删除记录"].exists)
        app.buttons["history.retry"].tap()
        XCTAssertTrue(app.staticTexts["没有删除记录"].waitForExistence(timeout: 5))
        attach("F024-history-empty")
    }
    func testHistoryLargeOpaqueKeepsDoneReachable() throws {
        continueAfterFailure = false
        let app = open(["--reduced-transparency-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["deletion.history.close"].isHittable)
        let scroll = app.scrollViews["history.scroll"]
        XCTAssertLessThanOrEqual(scroll.frame.maxY, app.buttons["deletion.history.close"].frame.minY)
        scroll.swipeUp(); scroll.swipeUp()
        let last = app.staticTexts["5 项 · 结果待核对"]
        for _ in 0..<5 where !last.isHittable || last.frame.maxY > scroll.frame.maxY { scroll.swipeUp() }
        XCTAssertTrue(last.isHittable)
        XCTAssertLessThanOrEqual(last.frame.maxY, scroll.frame.maxY)
        attach("F024-history-large-opaque")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
        app.buttons["deletion.history.close"].tap()
        XCTAssertTrue(app.buttons["打开记录"].waitForExistence(timeout: 5))
    }
}
