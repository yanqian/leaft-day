import XCTest

@MainActor final class ReviewGlassTests: XCTestCase {
    func testGlassPillsAndOpaqueFallbackKeepNavigationReachable() throws {
        continueAfterFailure = false
        for opaque in [false, true] {
            let app = XCUIApplication(); app.resetAuthorizationStatus(for: .photos)
            app.launchArguments = ["--home-navigation-test-host", "-AppleLanguages", "(en)"]
            if opaque { app.launchArguments.append("--reduced-transparency-test") }
            app.launch()
            let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            XCTAssertTrue(system.buttons["Allow Full Access"].waitForExistence(timeout: 10)); system.buttons["Allow Full Access"].tap()
            XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 15)); app.buttons["home.continue"].tap()
            app.tapReviewCanvas()
            let previous = app.buttons["上一项"], next = app.buttons["下一项"]
            XCTAssertTrue(next.waitForExistence(timeout: 5)); XCTAssertFalse(previous.isEnabled)
            XCTAssertGreaterThanOrEqual(next.frame.width, 44); XCTAssertGreaterThanOrEqual(next.frame.height, 44)
            XCTAssertLessThan(app.buttons["review.back"].frame.midY, app.frame.midY)
            XCTAssertGreaterThan(next.frame.midY, app.frame.height * 0.7)
            XCTAssertTrue(app.frame.contains(app.buttons["review.pending"].frame))
            for index in 0..<3 {
                if index > 0 { next.tap() }
                XCTAssertEqual(app.staticTexts["review.position"].label, "本轮剩余 \(3 - index) 项")
                let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                shot.name = "F009-v3-\(opaque ? "opaque" : "glass")-\(index)"; shot.lifetime = .keepAlways; add(shot)
            }
            XCTAssertFalse(next.isEnabled)
            app.terminate()
        }
    }
}
