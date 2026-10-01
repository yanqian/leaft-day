import XCTest
@testable import SwipeGo

@MainActor final class BundledBackdropTests: XCTestCase {
    func testBundledAtmosphereDecodesWithoutPhotoAuthorization() {
        XCTAssertNotNil(CoastalBackdrop.image)
        XCTAssertEqual(CoastalBackdrop.image?.size.width, 1024)
        XCTAssertEqual(CoastalBackdrop.image?.size.height, 1536)
    }
}
