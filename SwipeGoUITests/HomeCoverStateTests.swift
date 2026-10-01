import XCTest

@MainActor final class HomeCoverStateTests: XCTestCase {
    func testMaximumTypeCoverStatesRemainReadable() throws {
        continueAfterFailure = false
        let cases = [("empty", "这一天暂无照片"), ("loading", "正在载入照片"),
                     ("downloading", "正在从 iCloud 载入"), ("offline", "离线，封面暂不可用"),
                     ("unavailable", "封面暂不可用")]
        for hero in [false, true] {
        for (state, message) in cases {
            let app = XCUIApplication(); app.terminate()
            app.launchArguments = ["--home-cover-test-host", "--cover-\(state)",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            if state == "unavailable" { app.launchArguments.append("--reduced-transparency-test") }
            if hero { app.launchArguments.append("--cover-hero") }
            app.launch()
            let title = app.staticTexts["home.cover-title"]
            let status = app.staticTexts["home.cover-status"]
            XCTAssertTrue(status.waitForExistence(timeout: 10))
            XCTAssertEqual(status.label, hero && state == "empty" ? "这段时光没有照片封面" : message)
            XCTAssertTrue(status.isHittable)
            XCTAssertTrue(app.frame.contains(status.frame))
            XCTAssertGreaterThanOrEqual(status.frame.minY, title.frame.maxY, "Status must follow title without overlap")
            try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped])
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "F009-\(hero ? "hero" : "cover")-\(state)-maximum-type"
            shot.lifetime = .keepAlways; add(shot)
        }
        }
    }
}
