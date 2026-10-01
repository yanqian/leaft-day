import XCTest

@MainActor final class DeletionResultGlassTests: XCTestCase {
    func testAllReceiptStatesAndMaximumTextRemainReadable() {
        continueAfterFailure = false
        for large in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["--deletion-result-test-host"]
            if large { app.launchArguments += ["--reduced-transparency-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
            app.launch()
            let next = app.buttons["result.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            for index in 0..<5 {
                let scroll = app.scrollViews["result.scroll"]
                XCTAssertLessThanOrEqual(scroll.frame.maxY, next.frame.minY)
                for _ in 0..<5 where !app.staticTexts["deletion.remaining"].isHittable { scroll.swipeUp() }
                XCTAssertTrue(app.staticTexts["deletion.remaining"].isHittable)
                XCTAssertEqual(app.staticTexts["deletion.remaining"].label, index == 0 ? "待删清单已清空" : "待删记录仍保留，未自动清空")
                XCTAssertFalse(app.buttons["deletion.execute"].exists)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "F015-result-\(index)-\(large ? "large" : "normal")"; shot.lifetime = .keepAlways; add(shot)
                next.tap()
            }
            app.terminate()
        }
    }
}
