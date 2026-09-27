import XCTest
@testable import SwipeGo

final class ReviewGestureTests: XCTestCase {
    func testAxisLocksAndEmitsOnceForCapturedAsset() {
        var router = ReviewGestureRouter()
        router.update(x: 30, y: 2, assetID: "a", blocked: false)
        router.update(x: 90, y: 200, assetID: "a", blocked: false)
        XCTAssertEqual(router.end(x: 90, y: 200, currentID: "a", blocked: false), ReviewIntent(assetID: "a", kind: .previous))
        XCTAssertNil(router.end(x: 90, y: 200, currentID: "a", blocked: false))
        router.update(x: 0, y: -30, assetID: "a", blocked: false)
        XCTAssertNil(router.end(x: 0, y: -100, currentID: "b", blocked: false))
    }
    func testCancellingIdleDoesNotPoisonNextDrag() {
        var router = ReviewGestureRouter()
        router.cancel()
        router.update(x: -30, y: 0, assetID: "a", blocked: false)
        XCTAssertEqual(router.end(x: -100, y: 0, currentID: "a", blocked: false)?.kind, .next)
        router.update(x: 0, y: -30, assetID: "a", blocked: false)
        router.cancel()
        XCTAssertNil(router.end(x: 0, y: -100, currentID: "a", blocked: false))
    }
    func testThresholdDiagonalZoomAndIntentDirections() {
        var router = ReviewGestureRouter()
        router.update(x: 30, y: 30, assetID: "a", blocked: false)
        XCTAssertNil(router.end(x: 100, y: 100, currentID: "a", blocked: false))
        router.update(x: 30, y: 0, assetID: "a", blocked: false)
        XCTAssertNil(router.end(x: 64, y: 0, currentID: "a", blocked: false))
        for (x, y, kind) in [(-100.0, 0.0, ReviewIntent.Kind.next), (0, -100, .pending), (0, 100, .favorite)] {
            router.update(x: x / 2, y: y / 2, assetID: "asset", blocked: false)
            XCTAssertEqual(router.end(x: x, y: y, currentID: "asset", blocked: false)?.kind, kind)
        }
        router.update(x: 100, y: 0, assetID: "a", blocked: true)
        XCTAssertNil(router.end(x: 100, y: 0, currentID: "a", blocked: false))
    }
}
