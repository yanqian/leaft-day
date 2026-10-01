import XCTest
@testable import SwipeGo

@MainActor final class ReviewContinuityTests: XCTestCase {
    let timeline = ReviewTimeline(timeZone: TimeZone(secondsFromGMT: 0)!)
    let base = Date(timeIntervalSince1970: 1_735_689_600)
    func asset(_ index: Int, dated: Bool = true) -> PhotoAssetSnapshot {
        let date = dated ? base.addingTimeInterval(Double(index) * 86400) : nil
        return .init(id: "id-\(index)", kind: index % 2 == 0 ? .photo : .video, creationDate: date, modificationDate: date, width: 100, height: 100, duration: 0, isFavorite: false, isLivePhoto: false)
    }
    func library(_ assets: [PhotoAssetSnapshot], permission: LibraryPermission = .full) -> LibrarySnapshot {
        .init(permission: permission, assets: assets, sharedLibraryMembershipVerified: false)
    }
    func storeURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: dir) }
        return dir.appendingPathComponent("Intent.store")
    }
    func testRecentAndRandomSingleSegmentsHaveBoundedStableRanges() {
        struct Seed: RandomNumberGenerator { var value: UInt64 = 99; mutating func next() -> UInt64 { value = value &* 6364136223846793005 &+ 1; return value } }
        let assets = (0..<90).map { asset($0) }
        let recent = timeline.recent(in: assets.reversed())!
        XCTAssertEqual(recent.assetIDs, Array(assets.suffix(60)).map(\.id))
        var a = Seed(); var b = Seed()
        let random = timeline.random(in: assets, using: &a)!
        XCTAssertEqual(random.assetIDs.count, 12)
        XCTAssertEqual(random, timeline.random(in: assets.reversed(), using: &b))
        XCTAssertTrue(random.title(calendar: timeline.calendar).contains(" – "))
        XCTAssertEqual(timeline.random(in: [assets[0]], using: &a)?.assetIDs, [assets[0].id])
        XCTAssertNil(timeline.random(in: [], using: &a))
        let unknown = timeline.random(in: [asset(0, dated: false), asset(1, dated: false)], using: &a)
        XCTAssertEqual(unknown?.title(calendar: timeline.calendar), "日期未知")
        XCTAssertTrue(timeline.batch([asset(0), asset(1, dated: false)])!.title(calendar: timeline.calendar).contains("含日期未知"))
    }
    func testContinuationAppendsAtMostSixtyAndPersistsWithoutReordering() async throws {
        let url = try storeURL(); let store = try LocalStateStore(url: url)
        let assets = (0..<75).map { asset($0) }
        let session = ReviewSession(store: store); session.updateLibrary(library(assets))
        try await session.start(timeline.batch(Array(assets.prefix(2)))!, mode: .continuous)
        try await session.move(by: 1); try await session.move(by: 1)
        XCTAssertEqual(session.state?.assetIDs, Array(assets.prefix(62)).map(\.id))
        XCTAssertEqual(session.state?.cursor, 2)
        try await session.move(by: -1); XCTAssertEqual(session.currentID, assets[1].id)
        let restored = ReviewSession(store: try LocalStateStore(url: url)); restored.updateLibrary(library(assets)); try await restored.restore()
        XCTAssertEqual(restored.state, session.state); XCTAssertEqual(restored.state?.mode, .continuous)
    }
    func testAnniversaryOnlyExpandsAfterExplicitActionAndUsesScopedAssets() async throws {
        let assets = (0..<4).map { asset($0) }
        let session = ReviewSession(store: try LocalStateStore(url: storeURL()), assetScope: Set(assets.prefix(3).map(\.id)))
        session.updateLibrary(library(assets))
        try await session.start(timeline.batch([assets[1]])!, mode: .anniversary)
        XCTAssertFalse(session.canGoForward); try await session.move(by: 1)
        XCTAssertEqual(session.state?.assetIDs, [assets[1].id]); XCTAssertEqual(session.state?.mode, .anniversary)
        XCTAssertEqual(session.nearbySegment?.assetIDs, [assets[0].id, assets[2].id])
        try await session.exploreNearby()
        XCTAssertEqual(session.state?.assetIDs, [assets[0].id, assets[2].id]); XCTAssertEqual(session.state?.mode, .continuous)
        try await session.move(by: 1); XCTAssertFalse(session.canGoForward, "Never append out-of-scope asset 3")
        session.updateLibrary(library(assets, permission: .denied))
        XCTAssertNil(session.nearbySegment); XCTAssertFalse(session.canGoForward)
    }
    func testFailedExtensionAndLegacyUpgradePreserveSavedCursorAndIDs() async throws {
        let url = try storeURL(); let store = try LocalStateStore(url: url)
        let assets = (0..<3).map { asset($0) }
        let legacy = SessionState(id: UUID(), assetIDs: [assets[0].id], cursor: 0, updatedAt: .distantPast)
        try await store.saveSession(legacy)
        let session = ReviewSession(store: store); session.updateLibrary(library(assets)); try await session.restore()
        try await session.enableLegacyContinuation()
        XCTAssertEqual(session.state?.assetIDs, legacy.assetIDs); XCTAssertEqual(session.state?.cursor, 0)
        let readOnly = ReviewSession(store: try LocalStateStore(url: url, allowsSave: false))
        readOnly.updateLibrary(library(assets)); try await readOnly.restore()
        let before = readOnly.state
        do { try await readOnly.move(by: 1); XCTFail() } catch { }
        XCTAssertEqual(readOnly.state, before)
        let oldJSON = try JSONEncoder().encode(legacy)
        XCTAssertNil(try JSONDecoder().decode(SessionState.self, from: oldJSON).mode)
    }
    func testMissingAnchorCannotInventContinuationAndOneItemIsExplicit() async throws {
        let session = ReviewSession(store: try LocalStateStore(url: storeURL()))
        let one = asset(0); session.updateLibrary(library([one]))
        try await session.start(timeline.batch([one])!, mode: .continuous)
        XCTAssertFalse(session.canGoForward); XCTAssertNil(session.nearbySegment)
        XCTAssertEqual(session.endMessage, "当前可访问的图库只有这一项")
        session.updateLibrary(library([asset(1)], permission: .limited))
        XCTAssertFalse(session.canGoForward); XCTAssertNil(session.nearbySegment)
        if case .unavailable = session.current {} else { XCTFail() }
        XCTAssertEqual(session.state?.assetIDs, [one.id])
        XCTAssertNil(session.endMessage)
    }
    func testRandomPrefersMultipleAndCapsLongSegmentAtSixty() {
        var rng = SystemRandomNumberGenerator()
        let sameDay = (0..<75).map { index in
            PhotoAssetSnapshot(id: "same-\(index)", kind: .photo, creationDate: base, modificationDate: base,
                               width: 10, height: 10, duration: 0, isFavorite: false, isLivePhoto: false)
        }
        let all = sameDay + [asset(90)]
        for _ in 0..<5 {
            let selected = timeline.random(in: all, using: &rng)!
            XCTAssertEqual(selected.assetIDs.count, 60)
            XCTAssertTrue(selected.assetIDs.allSatisfy { $0.hasPrefix("same-") })
            XCTAssertEqual(selected.start, base); XCTAssertEqual(selected.end, base)
        }
    }

}
