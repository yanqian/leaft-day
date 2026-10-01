import XCTest

@MainActor final class PhotoPaletteUITests: XCTestCase {
    func testPaletteChangesOnNativeGlassWithoutPhotoWallpaper() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--palette-test-host"]; app.launch()
        let token = app.staticTexts["palette.token"]; XCTAssertTrue(token.waitForExistence(timeout: 10))
        let fallback = token.label; var seen = Set<String>()
        for name in ["海蓝", "草木", "暖桃"] {
            app.buttons[name].tap()
            XCTAssertNotEqual(token.label, fallback); seen.insert(token.label)
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "F026-\(name)"; shot.lifetime = .keepAlways; add(shot)
        }
        XCTAssertEqual(seen.count, 3)
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription, .hitRegion])
        app.buttons["默认"].tap(); XCTAssertEqual(token.label, fallback)
    }
}
