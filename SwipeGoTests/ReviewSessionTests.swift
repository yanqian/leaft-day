import XCTest
@testable import SwipeGo

@MainActor final class ReviewSessionTests: XCTestCase {
    let timeline = ReviewTimeline(timeZone: TimeZone(secondsFromGMT: 0)!)
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func asset(_ id: String, _ date: Date?, video: Bool = false) -> PhotoAssetSnapshot {
        PhotoAssetSnapshot(id: id, kind: video ? .video : .photo, creationDate: date, modificationDate: date,
                           width: 100, height: 100, duration: video ? 2 : 0, isFavorite: false, isLivePhoto: false)
    }
    func library(_ assets: [PhotoAssetSnapshot], permission: LibraryPermission = .full) -> LibrarySnapshot {
        LibrarySnapshot(permission: permission, assets: assets, sharedLibraryMembershipVerified: false)
    }
    func storeURL() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("Intent.store")
    }
    func testStableMixedOrderDayGapAndUnknownDates() {
        let base = date("2025-09-27T10:00:00Z")
        let assets = [asset("z", nil), asset("b", base, video: true), asset("a", base),
                      asset("c", base.addingTimeInterval(7201)), asset("d", date("2025-09-28T00:00:00Z"))]
        let expected = [["a", "b"], ["c"], ["d"], ["z"]]
        XCTAssertEqual(timeline.segments(in: assets).map(\.assetIDs), expected)
        XCTAssertEqual(timeline.segments(in: assets.reversed()).map(\.assetIDs), expected)
        XCTAssertEqual(timeline.segments(in: assets).last?.title(calendar: timeline.calendar), "日期未知")
        XCTAssertEqual(timeline.segments(in: assets + [assets[0]]).flatMap(\.assetIDs).count, 5)
    }
    func testStrictAnniversaryLeapDayEmptyAndTimeZone() {
        let leap = date("2024-02-29T12:00:00Z")
        XCTAssertNil(timeline.lastYearDate(relativeTo: leap))
        XCTAssertNil(timeline.lastYearToday(in: [asset("near", date("2025-09-26T12:00:00Z"))], today: date("2026-09-27T12:00:00Z")))
        let assets = [asset("late", date("2025-09-27T23:59:59Z")), asset("early", date("2025-09-27T00:00:00Z")), asset("next", date("2025-09-28T00:00:00Z"))]
        XCTAssertEqual(timeline.lastYearToday(in: assets, today: date("2026-09-27T12:00:00Z"))?.assetIDs, ["early", "late"])
        let singapore = ReviewTimeline(timeZone: TimeZone(identifier: "Asia/Singapore")!)
        XCTAssertEqual(singapore.lastYearToday(in: assets, today: date("2026-09-27T18:00:00Z"))?.assetIDs, ["late", "next"])
        let dst = ReviewTimeline(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        XCTAssertEqual(dst.segments(in: [asset("a", date("2025-03-09T09:30:00Z")), asset("b", date("2025-03-09T10:30:00Z"))]).count, 1)
    }
    func testRandomSelectsWholeSegmentAndEmptyIsNil() {
        struct Seed: RandomNumberGenerator { var value: UInt64 = 27; mutating func next() -> UInt64 { value = value &* 6364136223846793005 &+ 1; return value } }
        var first = Seed(); var second = Seed()
        let base = date("2025-01-01T12:00:00Z")
        let assets = [asset("a", base), asset("b", base.addingTimeInterval(1), video: true), asset("c", base.addingTimeInterval(86400))]
        let selected = timeline.random(in: assets, using: &first)
        XCTAssertEqual(selected, timeline.random(in: assets, using: &second))
        XCTAssertTrue(timeline.segments(in: assets).contains(selected!))
        XCTAssertNil(timeline.random(in: [], using: &first))
    }
    func testRealDiskRestoreCursorAndMissingAssetRetainsIntent() async throws {
        let url = try storeURL(); let assets = [asset("a", .distantPast), asset("b", .distantPast, video: true)]
        var review: ReviewSession? = ReviewSession(store: try LocalStateStore(url: url))
        review!.updateLibrary(library(assets)); try await review!.start(timeline.segments(in: assets)[0])
        try await review!.move(by: 1); XCTAssertEqual(review!.currentID, "b")
        let saved = review!.state; review = nil
        let reopened = ReviewSession(store: try LocalStateStore(url: url))
        reopened.updateLibrary(library([assets[0]], permission: .limited)); try await reopened.restore()
        XCTAssertEqual(reopened.state, saved)
        if case .unavailable = reopened.current {} else { XCTFail("Missing is not a deletion receipt") }
        try await reopened.move(by: -1); XCTAssertEqual(reopened.current, .available(assets[0]))
        reopened.updateLibrary(library([], permission: .denied))
        if case .unavailable = reopened.current {} else { XCTFail() }
        let store = try LocalStateStore(url: url)
        let pending = try await store.pending(); let operations = try await store.operations()
        XCTAssertTrue(pending.isEmpty); XCTAssertTrue(operations.isEmpty)
        XCTAssertEqual(reopened.state?.assetIDs, ["a", "b"])
    }
    func testRealSaveFailurePreservesCursorAndLatestSessionWins() async throws {
        let url = try storeURL(); let assets = [asset("a", .distantPast), asset("b", .distantPast)]
        let writer = ReviewSession(store: try LocalStateStore(url: url)); writer.updateLibrary(library(assets))
        try await writer.start(timeline.segments(in: assets)[0], now: date("2026-01-01T00:00:00Z"))
        try await writer.start(timeline.segments(in: assets)[0], now: date("2026-01-02T00:00:00Z"))
        let lastID = writer.state?.id
        let readOnly = ReviewSession(store: try LocalStateStore(url: url, allowsSave: false))
        readOnly.updateLibrary(library(assets)); try await readOnly.restore(); XCTAssertEqual(readOnly.state?.id, lastID)
        do { try await readOnly.move(by: 1); XCTFail("Must report real save error") } catch { }
        XCTAssertEqual(readOnly.state?.cursor, 0); XCTAssertFalse(readOnly.isSaving)
        let reread = try await LocalStateStore(url: url).latestSession()
        XCTAssertEqual(reread?.cursor, 0)
    }
    func testRemainingExcludesCurrentAcrossNavigationAndRestore() async throws {
        let path = try storeURL()
        let assets = [asset("a", .distantPast), asset("b", .distantPast), asset("c", .distantPast)]
        let review = ReviewSession(store: try LocalStateStore(url: path))
        review.updateLibrary(library(assets))
        XCTAssertEqual(review.remainingCount, 0)
        try await review.start(timeline.segments(in: assets)[0])
        XCTAssertEqual(review.remainingCount, 2)
        try await review.move(by: 1)
        XCTAssertEqual(review.remainingCount, 1)
        try await review.move(by: 1)
        XCTAssertEqual(review.remainingCount, 0)
        XCTAssertFalse(review.canGoForward)
        XCTAssertFalse(review.isComplete, "Zero following items does not complete the current photo")
        let restored = ReviewSession(store: try LocalStateStore(url: path))
        restored.updateLibrary(library(assets)); try await restored.restore()
        XCTAssertEqual(restored.currentID, "c"); XCTAssertEqual(restored.remainingCount, 0)
        try await restored.move(by: -1)
        XCTAssertEqual(restored.remainingCount, 1)
        try await restored.start(ReviewSegment(assetIDs: ["a"], start: nil, end: nil))
        XCTAssertEqual(restored.remainingCount, 0)
        XCTAssertEqual(restored.currentID, "a"); XCTAssertFalse(restored.isComplete)
    }

}
