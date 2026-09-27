import XCTest
import Photos
@testable import SwipeGo

@MainActor
final class PhotoLoaderTests: XCTestCase {
    final class Transport: PhotoTransport {
        var callbacks: [UUID: @MainActor (PhotoLoadEvent) -> Void] = [:]
        var keys: [PhotoRequestKey] = []
        var networks: [Bool] = []
        var cancelled: [UUID] = []
        func request(_ key: PhotoRequestKey, network: Bool, receive: @escaping @MainActor (PhotoLoadEvent) -> Void) -> UUID {
            let token = UUID(); callbacks[token] = receive; keys.append(key); networks.append(network); return token
        }
        func cancel(_ token: UUID) { cancelled.append(token) }
    }
    private func key(_ id: String) -> PhotoRequestKey { .init(assetID: id, width: 100, height: 100) }
    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }
    func testLateResultCannotReplaceCurrentAndPrefetchBounded() {
        let transport = Transport(); let loader = PhotoLoader(transport: transport)
        loader.load(key("a"), neighbors: (0..<30).map { key("n\($0)") })
        XCTAssertEqual(transport.keys.count, 3)
        XCTAssertEqual(transport.networks, [true, false, false])
        let stale = Array(transport.callbacks.values)
        loader.load(key("b"))
        XCTAssertEqual(transport.cancelled.count, 3)
        for callback in stale { callback(.image(image())) }
        XCTAssertEqual(loader.current, key("b"))
        if case .loading = loader.state {} else { XCTFail("Stale image replaced current state") }
        XCTAssertEqual(loader.cache.count, 0)
    }
    func testReleaseCancelsOutstandingRequests() {
        let transport = Transport()
        var loader: PhotoLoader? = PhotoLoader(transport: transport)
        loader?.load(key("a"))
        loader = nil
        XCTAssertEqual(transport.cancelled.count, 1)
    }
    func testCacheBudgetLRUAndContentVersion() {
        let cache = PhotoMemoryCache(byteLimit: 100_000, countLimit: 2)
        cache.insert(image(), for: key("a")); cache.insert(image(), for: key("b"))
        _ = cache.image(for: key("a")); cache.insert(image(), for: key("c"))
        XCTAssertNil(cache.image(for: key("b")))
        XCTAssertLessThanOrEqual(cache.bytes, cache.byteLimit)
        XCTAssertEqual(cache.count, 2)
        XCTAssertNil(cache.image(for: .init(assetID: "a", version: .now, width: 100, height: 100)))
        cache.invalidate(assetID: "a"); XCTAssertNil(cache.image(for: key("a")))
        let tiny = PhotoMemoryCache(byteLimit: 1); tiny.insert(image(), for: key("a")); XCTAssertEqual(tiny.count, 0)
    }
    func testOfflineAndRetryAreNotSuccess() {
        let transport = Transport(); let loader = PhotoLoader(transport: transport)
        loader.load(key("a"))
        transport.callbacks.values.first?(.offline)
        if case .offline = loader.state {} else { XCTFail("Offline hidden") }
        loader.retry(); XCTAssertEqual(transport.keys.count, 2)
        if case .loading = loader.state {} else { XCTFail("Retry did not start") }
        loader.releaseMemory(); XCTAssertNil(loader.current); XCTAssertEqual(loader.cache.bytes, 0)
    }
    func testNativeLocalPhotoLoadWhenAuthorized() async throws {
        let snapshot = await PhotoLibraryGateway().snapshot()
        guard let photo = snapshot.assets.first(where: { $0.kind == .photo }) else {
            throw XCTSkip("No authorized local photo; real loading must be run after permission UI tests")
        }
        let loader = PhotoLoader()
        loader.load(.init(assetID: photo.id, version: photo.modificationDate, width: 240, height: 240), network: false)
        for _ in 0..<100 {
            if case .ready(let image) = loader.state {
                XCTAssertGreaterThan(image.size.width, 0); loader.releaseMemory(); return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("Native local photo did not load")
    }
}
