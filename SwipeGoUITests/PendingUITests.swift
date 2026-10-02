import XCTest

@MainActor final class PendingUITests: XCTestCase {
    private func open(reducedMotion: Bool = false, failure: String? = nil, anniversary: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.terminate(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--pending-test-host", "-AppleLanguages", "(en)"]
        if reducedMotion { app.launchArguments.append("--reduced-motion-test") }
        if anniversary { app.launchArguments.append("--pending-anniversary-test") }
        if let failure { app.launchArguments.append("--pending-failure=\(failure)") }
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["review.photo"].waitForExistence(timeout: 10))
        return app
    }
    private func expect(_ app: XCUIApplication, _ text: String) {
        let state = app.staticTexts["review.test-state"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: state)], timeout: 10), .completed, state.label)
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testMarkAdvancesUndoReturnsAndRestartPreservesCursor() {
        continueAfterFailure = false
        let app = open()
        expect(app, "pending=0")
        app.descendants(matching: .any)["review.photo"].swipeUp()
        expect(app, "pending=1"); expect(app, "cursor=1")
        XCTAssertTrue(app.buttons["review.feedback-undo"].waitForExistence(timeout: 5))
        app.buttons["review.feedback-undo"].tap(); expect(app, "pending=0"); expect(app, "cursor=0")
        app.descendants(matching: .any)["review.photo"].swipeUp(); expect(app, "cursor=1")
        app.tapReviewCanvas()
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 1 项")
        XCTAssertEqual(app.buttons["review.pending"].label, "待删 1")
        attach(app, "F023-next-after-swipe")
        app.terminate(); app.launchArguments.append("--preserve-review-store"); app.launch()
        expect(app, "pending=1"); expect(app, "firstPending=true"); expect(app, "cursor=1")
        app.tapReviewCanvas(); XCTAssertFalse(app.buttons["review.undo"].isEnabled)
        app.buttons["review.favorite"].tap()
        XCTAssertTrue(app.staticTexts["review.feedback"].waitForExistence(timeout: 5))
        app.buttons["review.pending"].tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 5)); app.buttons["取消"].tap()
        expect(app, "pending=1"); expect(app, "cursor=1")
        app.buttons["review.pending"].tap()
        XCTAssertTrue(app.buttons["仍加入待删"].waitForExistence(timeout: 5)); app.buttons["仍加入待删"].tap()
        expect(app, "pending=2"); expect(app, "cursor=2")
        XCTAssertTrue(app.descendants(matching: .any)["video.surface"].waitForExistence(timeout: 10))
        app.buttons["review.undo"].tap(); expect(app, "pending=1"); expect(app, "cursor=1")
        XCTAssertEqual(app.buttons["review.favorite"].label, "已收藏")
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 1 项")
    }
    func testReducedMotionLastItemCompletionAndUndo() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = open(reducedMotion: true)
        app.tapReviewCanvas()
        for index in 1...3 {
            app.buttons["review.pending"].tap(); expect(app, "pending=\(index)")
            if index < 3 { expect(app, "cursor=\(index)") }
        }
        XCTAssertTrue(app.staticTexts["review.completed"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 0 项")
        XCTAssertFalse(app.descendants(matching: .any)["video.surface"].exists)
        XCTAssertFalse(app.buttons["review.pending"].isEnabled)
        attach(app, "F023-completed-reduced-motion")
        app.buttons["review.undo"].tap(); expect(app, "pending=2")
        XCTAssertTrue(app.descendants(matching: .any)["video.surface"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 0 项")
        app.buttons["review.pending"].tap()
        XCTAssertTrue(app.staticTexts["review.completed"].waitForExistence(timeout: 10))
        app.terminate(); app.launchArguments.append("--preserve-review-store"); app.launch()
        XCTAssertTrue(app.staticTexts["review.completed"].waitForExistence(timeout: 10))
        expect(app, "pending=3")
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 0 项")
    }
    func testRealHomeCompletionKeepsLandscapeUndo() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.terminate(); app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--home-navigation-test-host", "--reduced-motion-test", "-AppleLanguages", "(en)"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15)); app.buttons["home.continue"].tap()
        app.tapReviewCanvas()
        for count in stride(from: 2, through: 0, by: -1) {
            app.buttons["review.pending"].tap()
            if app.buttons["仍加入待删"].exists { app.buttons["仍加入待删"].tap() }
            let predicate = NSPredicate(format: "label == %@", "剩余 \(max(0, count - 1)) 项")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: app.staticTexts["review.position"])], timeout: 10), .completed)
        }
        XCTAssertTrue(app.staticTexts["review.completed"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)], timeout: 10), .completed)
        XCTAssertTrue(app.buttons["review.undo"].isHittable)
        XCTAssertTrue(app.frame.contains(app.buttons["review.undo"].frame))
        XCTAssertTrue(app.buttons["review.completed-back"].isHittable)
        XCTAssertFalse(app.staticTexts["review.feedback"].exists, "Completion must not overlay a second toast on its return action")
        XCTAssertTrue(app.frame.contains(app.buttons["review.completed-back"].frame))
        XCTAssertLessThanOrEqual(app.buttons["review.completed-back"].frame.maxY, app.buttons["review.undo"].frame.minY)
        XCTAssertLessThanOrEqual(app.buttons["review.completed-back"].frame.maxY, app.scrollViews["review.completed-scroll"].frame.maxY)
        attach(app, "F023-completed-landscape")
        app.buttons["review.undo"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["review.photo"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 0 项")
        app.buttons["review.back"].tap()
        XCTAssertTrue(app.buttons["home.pending"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.pending"].label.contains("待删 2 项"))
    }

    private func completeAll(_ app: XCUIApplication) {
        app.tapReviewCanvas()
        for count in 1...3 { app.buttons["review.pending"].tap(); expect(app, "pending=\(count)") }
        XCTAssertTrue(app.staticTexts["review.completed"].waitForExistence(timeout: 10))
    }
    func testCompletionUndoWriteFailureIsVisibleAndRetryable() {
        continueAfterFailure = false
        let app = open(reducedMotion: true, failure: "undo")
        completeAll(app)
        app.buttons["review.undo"].tap()
        let alert = app.alerts["待删操作未完成"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts["撤回未完成，请核对待删记录并重试。"].exists)
        expect(app, "pending=3")
        attach(app, "F023-completion-undo-write-failure")
        alert.buttons["好"].tap()
        XCTAssertTrue(app.buttons["review.undo"].isEnabled)
        app.buttons["review.undo"].tap(); expect(app, "pending=2")
        XCTAssertTrue(app.descendants(matching: .any)["video.surface"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 0 项")
    }
    func testCompletionUnmarkedButPositionFailedShowsRecovery() {
        continueAfterFailure = false
        let app = open(reducedMotion: true, failure: "position")
        completeAll(app)
        app.buttons["review.undo"].tap()
        let alert = app.alerts["待删操作未完成"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts["已撤回待删标记，照片仍保留，但回顾位置未恢复。可重试回到照片。"].exists)
        expect(app, "pending=2")
        alert.buttons["好"].tap()
        XCTAssertEqual(app.staticTexts["review.position"].label, "位置待恢复")
        XCTAssertFalse(app.buttons["review.undo"].isEnabled)
        attach(app, "F023-completion-position-recovery")
        XCTAssertTrue(app.buttons["review.restore-position"].isHittable)
        app.buttons["review.restore-position"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["video.surface"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 0 项")
        expect(app, "pending=2")
    }
    func testCompletionPreviousReturnsToEarlierUnmarkedAsset() {
        continueAfterFailure = false
        let app = open(reducedMotion: true)
        app.tapReviewCanvas()
        app.buttons["下一项"].tap(); expect(app, "cursor=1")
        app.buttons["下一项"].tap(); expect(app, "cursor=2")
        app.buttons["review.pending"].tap()
        XCTAssertTrue(app.staticTexts["review.completed"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["上一项"].isEnabled)
        app.buttons["上一项"].tap(); expect(app, "cursor=1")
        XCTAssertTrue(app.descendants(matching: .any)["review.photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["review.completed"].exists)
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 0 项")
        expect(app, "pending=1")
    }

    func testCompletionNearbyThenUndoRestoresOriginalPhotoAndSession() {
        continueAfterFailure = false
        let app = open(reducedMotion: true, anniversary: true)
        let state = app.staticTexts["review.test-state"].label
        let original = state.components(separatedBy: "current=")[1].components(separatedBy: " ")[0]
        app.tapReviewCanvas()
        app.buttons["review.pending"].tap()
        XCTAssertTrue(app.staticTexts["review.completed"].waitForExistence(timeout: 10))
        expect(app, "pending=1")
        XCTAssertTrue(app.buttons["review.nearby"].isHittable); app.buttons["review.nearby"].tap()
        XCTAssertFalse(app.staticTexts["review.completed"].exists)
        XCTAssertFalse(app.staticTexts["review.test-state"].label.contains("current=\(original) "))
        app.buttons["review.undo"].tap()
        expect(app, "pending=0"); expect(app, "current=\(original) ")
        XCTAssertEqual(app.staticTexts["review.position"].label, "剩余 0 项")
        XCTAssertFalse(app.buttons["下一项"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["review.photo"].exists)
        attach(app, "F023-cross-session-undo")
        app.terminate(); app.launchArguments.append("--preserve-review-store"); app.launch()
        expect(app, "current=\(original) "); expect(app, "pending=0")
    }

}
