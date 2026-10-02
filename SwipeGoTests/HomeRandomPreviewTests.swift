import XCTest
@testable import SwipeGo

@MainActor final class HomeRandomPreviewTests: XCTestCase {
    private func storeURL() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("Intent.store")
    }
    private func asset(_ id: String, seconds: TimeInterval, video: Bool = false) -> PhotoAssetSnapshot {
        let date = Date(timeIntervalSince1970: 1_750_000_000 + seconds)
        return .init(id: id, kind: video ? .video : .photo, creationDate: date, modificationDate: date,
                     width: 100, height: 100, duration: video ? 2 : 0, isFavorite: false, isLivePhoto: false)
    }
    private var assets: [PhotoAssetSnapshot] {
        [asset("a", seconds: 0), asset("b", seconds: 60, video: true),
         asset("c", seconds: 86400), asset("d", seconds: 86460)]
    }
    private func library(_ assets: [PhotoAssetSnapshot], permission: LibraryPermission = .full) -> LibrarySnapshot {
        .init(permission: permission, assets: assets, sharedLibraryMembershipVerified: false)
    }
    func testCoverAndOpenSharePreviewThenDismissSelectsDifferentMemory() async throws {
        let model = HomeModel(store: try LocalStateStore(url: storeURL()))
        model.updateLibrary(library(assets))
        let preview = try XCTUnwrap(model.randomSegment)
        let covers = model.coverCandidates(preview)
        XCTAssertFalse(covers.isEmpty)
        XCTAssertTrue(covers.allSatisfy { $0.kind == .photo && preview.assetIDs.contains($0.id) })
        XCTAssertLessThanOrEqual(covers.count, 3)
        await model.random()
        XCTAssertTrue(model.presentingReview)
        XCTAssertEqual(model.review.state?.assetIDs, preview.assetIDs)
        model.reviewDidDismiss()
        let next = try XCTUnwrap(model.randomSegment)
        XCTAssertNotEqual(next.assetIDs, preview.assetIDs)
        await model.random()
        XCTAssertEqual(model.review.state?.assetIDs, next.assetIDs)
    }
    func testOrdinaryRefreshAndOtherRouteDismissPreservePreview() async throws {
        let model = HomeModel(store: try LocalStateStore(url: storeURL()))
        model.updateLibrary(library(assets))
        let preview = try XCTUnwrap(model.randomSegment)
        for _ in 0..<5 {
            model.updateLibrary(library(assets.reversed()))
            XCTAssertEqual(model.randomSegment?.assetIDs, preview.assetIDs)
        }
        await model.resume()
        model.reviewDidDismiss()
        XCTAssertEqual(model.randomSegment?.assetIDs, preview.assetIDs)
        let modificationDate = Date.now
        let changed = assets.map { old in
            PhotoAssetSnapshot(id: old.id, kind: old.kind, creationDate: old.creationDate?.addingTimeInterval(60), modificationDate: modificationDate,
                width: old.width, height: old.height, duration: old.duration, isFavorite: old.isFavorite, isLivePhoto: old.isLivePhoto)
        }
        model.updateLibrary(library(changed))
        XCTAssertEqual(model.randomSegment?.assetIDs, preview.assetIDs)
        XCTAssertEqual(model.randomSegment?.start, changed.first { $0.id == preview.assetIDs.first }?.creationDate)
        XCTAssertEqual(model.coverCandidates(model.randomSegment).first?.modificationDate, changed.first?.modificationDate)
    }
    func testPermissionInvalidationScopeEmptyAndSingleVideo() async throws {
        let model = HomeModel(store: try LocalStateStore(url: storeURL()), assetScope: ["a", "b", "c"])
        model.updateLibrary(library(assets))
        XCTAssertFalse(try XCTUnwrap(model.randomSegment).assetIDs.contains("d"))
        model.updateLibrary(library(assets, permission: .denied))
        XCTAssertNil(model.randomSegment)
        await model.random()
        XCTAssertNil(model.review.state)
        model.updateLibrary(library([assets[2]], permission: .limited))
        XCTAssertEqual(model.randomSegment?.assetIDs, ["c"])
        await model.random(); model.reviewDidDismiss()
        XCTAssertEqual(model.randomSegment?.assetIDs, ["c"], "Only one available memory remains usable")
        model.updateLibrary(library([assets[1]], permission: .limited))
        XCTAssertEqual(model.randomSegment?.assetIDs, ["b"])
        XCTAssertTrue(model.coverCandidates(model.randomSegment).isEmpty, "Never substitute another collection's photo for a video")
        model.updateLibrary(library([]))
        XCTAssertNil(model.randomSegment)
    }
    func testFailedOpenDoesNotConsumeOrRotatePreview() async throws {
        let path = try storeURL()
        _ = try LocalStateStore(url: path)
        let model = HomeModel(store: try LocalStateStore(url: path, allowsSave: false))
        model.updateLibrary(library(assets))
        let preview = model.randomSegment
        await model.random()
        XCTAssertFalse(model.presentingReview)
        XCTAssertNotNil(model.message)
        model.reviewDidDismiss()
        XCTAssertEqual(model.randomSegment, preview)
        XCTAssertNil(model.review.state)
    }
    func testSeededAvoidanceUsesSparseAlternativeAndBoundedCandidates() throws {
        struct Seed: RandomNumberGenerator {
            var value: UInt64 = 27
            mutating func next() -> UInt64 { value = value &* 6364136223846793005 &+ 1; return value }
        }
        let timeline = ReviewTimeline()
        let mixed = Array(assets.prefix(3))
        var a = Seed(), b = Seed()
        let first = try XCTUnwrap(timeline.random(in: mixed, using: &a))
        XCTAssertEqual(first.assetIDs, ["a", "b"])
        let next = try XCTUnwrap(timeline.random(in: mixed, using: &a, avoiding: first))
        _ = timeline.random(in: mixed, using: &b)
        XCTAssertEqual(next, timeline.random(in: mixed, using: &b, avoiding: first))
        XCTAssertNotEqual(next.assetIDs, first.assetIDs)
        XCTAssertLessThanOrEqual(next.assetIDs.count, 12)
        let single = timeline.random(in: [assets[0]], using: &a)
        XCTAssertEqual(single, timeline.random(in: [assets[0]], using: &a, avoiding: single))
    }
}
