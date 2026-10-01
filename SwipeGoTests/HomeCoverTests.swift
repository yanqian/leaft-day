import XCTest
@testable import SwipeGo

@MainActor final class HomeCoverTests: XCTestCase {
    private func asset(_ id: String, video: Bool = false) -> PhotoAssetSnapshot {
        .init(id: id, kind: video ? .video : .photo, creationDate: nil, modificationDate: nil, width: 1200, height: 900, duration: 0, isFavorite: false, isLivePhoto: false)
    }
    private func settle() async { for _ in 0..<10 { await Task.yield() } }
    func testOnlyPhotosAndBoundedFallback() async {
        let transport = PhotoLoaderTests.Transport(); let loader = HomeCoverLoader(transport: transport)
        loader.load([asset("video", video: true)] + (0..<20).map { asset("p\($0)") })
        for index in 0..<3 {
            XCTAssertEqual(transport.keys.count, index + 1)
            let id = transport.keys.last!.assetID
            XCTAssertEqual(id, "p\(index)")
            let callback = transport.callbacks.first { !transport.cancelled.contains($0.key) }!
            transport.callbacks.removeValue(forKey: callback.key)
            callback.value(.unavailable); await settle()
        }
        XCTAssertEqual(transport.keys.count, 3)
        XCTAssertEqual(transport.networks, [true, true, true])
        if case .unavailable = loader.state {} else { XCTFail("Must stop with explicit unavailable state") }
    }
    func testNoPhotosDoesNotRequestVideo() {
        let transport = PhotoLoaderTests.Transport(); let loader = HomeCoverLoader(transport: transport)
        loader.load([asset("v", video: true)])
        XCTAssertTrue(transport.keys.isEmpty)
        if case .empty = loader.state {} else { XCTFail("Expected intentional no-photo cover") }
    }
    func testOfflineStillTriesLocalCandidateThenReportsOfflineAndRetries() async {
        let transport = PhotoLoaderTests.Transport(); let loader = HomeCoverLoader(transport: transport)
        loader.load([asset("one"), asset("two")])
        let first = transport.callbacks.first!
        first.value(.offline); await settle()
        XCTAssertEqual(transport.networks, [true, false], "Offline fallback must be local-only")
        transport.callbacks.first { $0.key != first.key }!.value(.needsDownload); await settle()
        if case .offline = loader.state {} else { XCTFail("Offline must be distinct") }
        loader.load([asset("one")]); XCTAssertEqual(transport.networks, [true, false, true])
    }
    func testCancelledAndPriorCandidateCannotReplaceNewCover() async {
        let transport = PhotoLoaderTests.Transport(); let loader = HomeCoverLoader(transport: transport)
        loader.load([asset("a"), asset("b")])
        let stale = transport.callbacks.values.first!
        stale(.unavailable); await settle()
        XCTAssertEqual(transport.keys.last?.assetID, "b")
        stale(.offline); await settle()
        if case .loading = loader.state {} else { XCTFail("Prior candidate overwrote state") }
        let ids = Set(transport.callbacks.keys)
        loader.load([asset("c")]); XCTAssertEqual(transport.cancelled.count, 1)
        for id in ids { transport.callbacks[id]?(.offline) }; await settle()
        if case .loading = loader.state {} else { XCTFail("Stale generation overwrote state") }
        loader.cancel(); XCTAssertEqual(transport.cancelled.count, 2)
    }
}
