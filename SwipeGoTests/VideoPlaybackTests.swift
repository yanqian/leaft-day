import XCTest
import AVFoundation
@testable import SwipeGo

@MainActor final class VideoPlaybackTests: XCTestCase {
    final class Transport: VideoTransport {
        var callbacks: [UUID: @MainActor (VideoResourceEvent) -> Void] = [:]
        var cancelled: [UUID] = []
        func request(assetID: String, receive: @escaping @MainActor (VideoResourceEvent) -> Void) -> UUID {
            let id = UUID(); callbacks[id] = receive; return id
        }
        func cancel(_ token: UUID) { cancelled.append(token) }
    }
    func testLateItemsAndRelease() {
        let transport = Transport(); var playback: VideoPlayback? = VideoPlayback(transport: transport)
        playback?.open("a"); let late = transport.callbacks.values.first!
        playback?.open("b")
        late(.offline)
        XCTAssertEqual(playback?.assetID, "b")
        if case .loading = playback?.state {} else { XCTFail("Old event changed new item") }
        XCTAssertEqual(transport.cancelled.count, 1)
        playback = nil; XCTAssertEqual(transport.cancelled.count, 2)
    }
    func testResourceFailuresAndRetry() {
        let transport = Transport(); let playback = VideoPlayback(transport: transport)
        playback.open("a"); let original = transport.callbacks.values.first!
        original(.progress(0.5))
        if case .loading(let progress) = playback.state { XCTAssertEqual(progress, 0.5) } else { XCTFail() }
        original(.offline)
        if case .offline = playback.state {} else { XCTFail() }
        playback.retry()
        XCTAssertEqual(transport.callbacks.count, 2)
        original(.failed("late failure"))
        if case .loading = playback.state {} else { XCTFail("Retry accepted stale failure") }
        let retry = transport.callbacks.first { $0.key != transport.cancelled.first }!.value
        retry(.unavailable)
        if case .unavailable = playback.state {} else { XCTFail() }
        playback.stop(); XCTAssertNil(playback.assetID)
    }
    func testRealAVPlayerFixtureAndStop() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "clip", withExtension: "mp4"))
        let transport = Transport(); let playback = VideoPlayback(transport: transport)
        playback.open("fixture")
        transport.callbacks.values.first?(.item(AVPlayerItem(url: url)))
        for _ in 0..<100 {
            if case .ready = playback.state { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        if case .ready = playback.state {} else { return XCTFail("Actual AVPlayer did not become ready") }
        XCTAssertTrue(playback.isMuted)
        XCTAssertTrue(playback.isPlaying)
        for _ in 0..<30 {
            if playback.position > 0.1 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertGreaterThan(playback.position, 0.1, "Real playback must advance")
        playback.togglePlayback(); XCTAssertFalse(playback.isPlaying)
        playback.toggleMute(); XCTAssertFalse(playback.player!.isMuted)
        playback.seek(to: 1); XCTAssertEqual(playback.position, 1, accuracy: 0.1)
        let old = try XCTUnwrap(playback.player)
        playback.stop(); XCTAssertNil(playback.player); XCTAssertNil(old.currentItem); XCTAssertEqual(old.rate, 0)
    }
    func testNativePhotoKitVideoWhenAuthorized() async throws {
        let library = await PhotoLibraryGateway().snapshot()
        guard let asset = library.assets.first(where: { $0.kind == .video }) else { throw XCTSkip("Run after real permission matrix selected video") }
        let playback = VideoPlayback(); playback.open(asset.id)
        for _ in 0..<100 {
            if case .ready = playback.state { playback.stop(); return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("Native PhotoKit video did not become ready")
    }
}
