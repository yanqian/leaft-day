#if !targetEnvironment(simulator)
import XCTest

@MainActor final class DeviceAcceptanceTests: XCTestCase {
    func testGeneratedFixtureEndToEndOnPhysicalDevice() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let runID = UUID().uuidString
        app.launchArguments = ["--device-acceptance=" + runID, "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["device.create"].waitForExistence(timeout: 15))
        app.buttons["device.create"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if system.buttons["Allow Full Access"].waitForExistence(timeout: 5) { system.buttons["Allow Full Access"].tap() }
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 30), app.debugDescription)
        app.buttons["home.continue"].tap()
        let photo = app.descendants(matching: .any)["review.photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["review.back"].exists)
        photo.swipeDown()
        app.tapReviewCanvas()
        XCTAssertTrue(app.buttons["review.favorite"].waitForExistence(timeout: 10))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "已收藏"), object: app.buttons["review.favorite"])], timeout: 15), .completed)
        for _ in 0..<3 { app.buttons["下一项"].tap() }
        XCTAssertTrue(app.sliders["video.progress"].waitForExistence(timeout: 20))
        app.sliders["video.progress"].adjust(toNormalizedSliderPosition: 0.5)
        let video = XCTAttachment(screenshot: app.screenshot()); video.name = "F018-device-video"; video.lifetime = .keepAlways; add(video)
        for _ in 0..<3 { app.buttons["上一项"].tap() }
        let similar = app.buttons["review.similar"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: similar)], timeout: 30), .completed, similar.label)
        similar.tap()
        XCTAssertTrue(app.buttons["comparison.keep.1"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["comparison.keep.1"].isEnabled, "Favorite must remain protected")
        app.buttons["comparison.zoom.2"].tap(); app.buttons["comparison.zoom-toggle"].tap(); app.buttons["comparison.zoom-close"].tap()
        app.buttons["comparison.keep.2"].tap()
        app.swipeUp(); app.buttons["comparison.confirm"].tap()
        XCTAssertTrue(app.staticTexts["comparison.saved"].waitForExistence(timeout: 10))
        let comparison = XCTAttachment(screenshot: app.screenshot()); comparison.name = "F018-device-comparison"; comparison.lifetime = .keepAlways; add(comparison)
        app.buttons["comparison.close"].tap(); app.buttons["review.back"].tap()
        app.buttons["home.pending"].tap()
        func submit() {
            app.buttons["deletion.prepare"].tap()
            XCTAssertTrue(app.switches["deletion.personal-library"].waitForExistence(timeout: 10))
            app.swipeUp(); app.switches["deletion.personal-library"].tap(); app.buttons["deletion.execute"].tap()
        }
        submit()
        XCTAssertTrue(system.alerts.firstMatch.waitForExistence(timeout: 15), system.debugDescription)
        system.alerts.buttons["Don’t Allow"].tap()
        XCTAssertTrue(app.staticTexts["deletion.result"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["deletion.result"].label.contains("取消"))
        app.buttons["deletion.cancel"].tap()
        submit()
        XCTAssertTrue(system.alerts.firstMatch.waitForExistence(timeout: 15))
        let confirmation = XCTAttachment(screenshot: system.screenshot()); confirmation.name = "F018-device-native-delete"; confirmation.lifetime = .keepAlways; add(confirmation)
        system.alerts.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["deletion.result"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["deletion.result"].label.contains("系统已确认删除本次清单"))
        app.buttons["deletion.cancel"].tap()
        if app.buttons["deletion.close"].exists { app.buttons["deletion.close"].tap() }
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10))
        app.buttons["device.refresh"].tap()
        let state = app.staticTexts["device.state"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "当前可见3项 · 收藏1项 · 待删0项"), object: state)], timeout: 15), .completed, state.label)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["device.state"].label.contains("当前可见3项"))
        let receipt = XCTAttachment(string: "runID=\(runID)\n\(app.staticTexts["device.state"].label)\nOnly manifest asset IDs were used; no cloud/Live Photo/performance claim.")
        receipt.name = "F018-device-run-receipt"; receipt.lifetime = .keepAlways; add(receipt)
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.terminate(); app.launch()
            XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 20))
        }
    }
    func testMemoryDuringGeneratedFixtureReviewOnPhysicalDevice() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--device-acceptance=" + UUID().uuidString, "-AppleLanguages", "(en)"]
        app.launch(); XCTAssertTrue(app.buttons["device.create"].waitForExistence(timeout: 15))
        app.buttons["device.create"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if system.buttons["Allow Full Access"].waitForExistence(timeout: 5) { system.buttons["Allow Full Access"].tap() }
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 30))
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTMemoryMetric(application: app), XCTClockMetric()], options: options) {
            app.buttons["home.continue"].tap()
            app.tapReviewCanvas()
            for _ in 0..<3 { app.buttons["下一项"].tap() }
            XCTAssertTrue(app.sliders["video.progress"].waitForExistence(timeout: 15))
            for _ in 0..<3 { app.buttons["上一项"].tap() }
            app.buttons["review.back"].tap()
        }
    }

}
#endif
