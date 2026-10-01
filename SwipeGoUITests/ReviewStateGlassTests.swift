import XCTest

@MainActor final class ReviewStateGlassTests: XCTestCase {
    func testEmptyUnavailableAndMediaFailuresUseReadableStates() {
        continueAfterFailure = false
        for large in [false, true] {
            for (mode, title) in [("empty", "暂无回顾片段"), ("unavailable", "当前项目不可用"), ("photo", "照片暂不可用"), ("video", "视频暂不可用"), ("comparison", "这一组暂时不可用")] {
                let app = XCUIApplication()
                app.launchArguments = ["--review-state=" + mode]
                if large { app.launchArguments += ["--reduced-transparency-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
                app.launch()
                XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 10))
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "F029-\(mode)-\(large ? "large" : "normal")"; shot.lifetime = .keepAlways; add(shot)
                if mode == "photo" || mode == "video" {
                    let retry = app.buttons[mode == "photo" ? "review.photo-retry" : "video.retry"]
                    let scroll = app.scrollViews.firstMatch
                    for _ in 0..<6 {
                        if retry.isHittable && retry.frame.maxY <= scroll.frame.maxY { break }
                        scroll.swipeUp()
                    }
                    XCTAssertTrue(retry.isHittable)
                    XCTAssertLessThanOrEqual(retry.frame.maxY, scroll.frame.maxY)
                    let actionShot = XCTAttachment(screenshot: app.screenshot())
                    actionShot.name = "F029-\(mode)-\(large ? "large" : "normal")-retry"; actionShot.lifetime = .keepAlways; add(actionShot)
                    retry.tap()
                    XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 5))
                }
                app.terminate()
            }
        }
    }
    func testLargestTypeLandscapeCompletionHasReadableViewport() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--review-state=completed", "--state-presentation-test", "--reduced-transparency-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["打开状态"].waitForExistence(timeout: 5)); app.buttons["打开状态"].tap()
        let title = app.staticTexts["review.completed"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)], timeout: 10), .completed)
        let scroll = app.scrollViews["review.completed-scroll"]
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "F029-completion-largest-landscape"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertGreaterThanOrEqual(scroll.frame.height, title.frame.height + 8, "The visible area must accommodate a complete line of the chosen text size")
        let back = app.buttons["review.completed-back"]
        for _ in 0..<6 where !back.isHittable || back.frame.maxY > scroll.frame.maxY { scroll.swipeUp() }
        XCTAssertTrue(back.isHittable)
        XCTAssertLessThanOrEqual(back.frame.maxY, scroll.frame.maxY)
        let returnShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); returnShot.name = "F029-completion-largest-landscape-return"; returnShot.lifetime = .keepAlways; add(returnShot)
    }

    func testLargestTypeLandscapeFailuresKeepTextAndRetryReachable() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        for (mode, heading) in [("photo", "照片暂不可用"), ("video", "视频暂不可用"), ("unavailable", "当前项目不可用")] {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication()
            app.launchArguments = ["--review-state=" + mode, "--state-presentation-test", "--reduced-transparency-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
            XCTAssertTrue(app.buttons["打开状态"].waitForExistence(timeout: 5)); app.buttons["打开状态"].tap()
            let title = app.staticTexts[heading].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 10)); title.tap()
            XCTAssertTrue(app.buttons["review.back"].waitForExistence(timeout: 5))
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)], timeout: 10), .completed)
            // The photo surface owns the accessibility identifier of its fallback scroll view.
            let scrollID = mode == "photo" ? "review.photo" : (mode == "video" ? "video.state-scroll" : "review.state-scroll")
            let scroll = app.scrollViews[scrollID]
            XCTAssertGreaterThanOrEqual(scroll.frame.height, title.frame.height + 8)
            if mode != "unavailable" {
                let retry = app.buttons[mode == "photo" ? "review.photo-retry" : "video.retry"]
                for _ in 0..<6 where !retry.isHittable || retry.frame.maxY > scroll.frame.maxY { scroll.swipeUp() }
                XCTAssertTrue(retry.isHittable)
                XCTAssertLessThanOrEqual(retry.frame.maxY, scroll.frame.maxY)
                let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "F029-\(mode)-largest-landscape-retry"; shot.lifetime = .keepAlways; add(shot)
            }
            XCTAssertTrue(app.buttons["review.back"].isHittable); app.buttons["review.back"].tap()
            app.terminate()
        }
    }

}
