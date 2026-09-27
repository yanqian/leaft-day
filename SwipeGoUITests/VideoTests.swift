import XCTest

final class VideoTests: XCTestCase {
    @MainActor func testActualVideoControlsAndLifecycle() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--video-test-host", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Allow Full Access"].waitForExistence(timeout: 5) { springboard.buttons["Allow Full Access"].tap() }
        let state = app.staticTexts["video.state"]
        func expect(_ text: String) {
            XCTAssertTrue(NSPredicate(format: "label CONTAINS %@", text).evaluate(with: state) ||
                XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: state)], timeout: 10) == .completed, "Expected \(text), actual \(state.label)")
        }
        expect("muted attached"); expect("started=true")
        if app.buttons["暂停"].exists { app.buttons["暂停"].tap() }; expect("paused")
        app.descendants(matching: .any)["video.surface"].swipeLeft(); expect("actions=1")
        app.buttons["开启声音"].tap(); expect("sound")
        app.sliders["video.progress"].adjust(toNormalizedSliderPosition: 0.5)
        let time = app.staticTexts["video.actual-time"]
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Double(time.label) ?? 0) > 0.5
        }, object: time)], timeout: 5) == .completed)
        expect("paused sound attached"); expect("actions=1")
        app.buttons["播放"].tap()
        app.buttons["切换会话"].tap(); expect("muted attached"); expect("retiredReleased=true")
        func stops() -> Int {
            Int(state.label.components(separatedBy: "stops=").last?.components(separatedBy: " ").first ?? "0") ?? 0
        }
        let beforeBackground = stops()
        XCUIDevice.shared.press(.home)
        app.activate(); expect("muted attached"); XCTAssertGreaterThan(stops(), beforeBackground)
        let beforeClose = stops()
        app.buttons["关闭视频"].tap(); expect("released"); XCTAssertGreaterThan(stops(), beforeClose)
        app.buttons["打开视频"].tap(); expect("muted attached")
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
}
