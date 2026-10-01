import XCTest

@MainActor extension XCUIApplication {
    func tapReviewCanvas(x: CGFloat = 0.5, y: CGFloat = 0.12) {
        let media = descendants(matching: .any).matching(NSPredicate(format: "identifier IN %@", ["review.photo", "video.surface"])).firstMatch
        XCTAssertTrue(media.waitForExistence(timeout: 15))
        media.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
    }
}
