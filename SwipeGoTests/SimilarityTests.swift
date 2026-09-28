import XCTest
import Photos
import Vision
import CoreML
@testable import SwipeGo

@MainActor final class SimilarityTests: XCTestCase {
    static func asset(_ id: String, date: Date = Date(timeIntervalSince1970: 1_700_000_000), version: Date = .distantPast) -> PhotoAssetSnapshot {
        PhotoAssetSnapshot(id: id, kind: .photo, creationDate: date, modificationDate: version, width: 100, height: 100, duration: 0, isFavorite: false, isLivePhoto: false)
    }
    actor Printer: FeaturePrinting {
        nonisolated let version = "controlled-v1"
        var calls = 0
        let delayed: Bool
        init(delayed: Bool = false) { self.delayed = delayed }
        func descriptor(for asset: PhotoAssetSnapshot) async throws -> Data {
            calls += 1
            if delayed { try await Task.sleep(for: .milliseconds(30)) }
            if asset.id == "unavailable" { throw SimilarityFailure.unavailable }
            return Data(asset.id.utf8)
        }
        func distance(_ a: Data, _ b: Data) -> Float {
            let values: [String: Float] = ["a": 0, "b": 0.08, "c": 0.16]
            return abs((values[String(decoding: a, as: UTF8.self)] ?? 0) - (values[String(decoding: b, as: UTF8.self)] ?? 0))
        }
    }
    func testCompleteLinkNoChainCacheAndVersionInvalidation() async throws {
        let printer = Printer(); let engine = SimilarityEngine(printer: printer)
        var assets = ["a", "b", "c", "unavailable"].map { Self.asset($0) }
        let first = try await engine.analyze(currentID: "a", assets: assets)
        XCTAssertEqual(first.groups.map(\.assetIDs), [["a", "b"]]); XCTAssertEqual(first.unavailableCount, 1)
        _ = try await engine.analyze(currentID: "a", assets: assets)
        let reused = await printer.calls; XCTAssertEqual(reused, 5)
        assets[0] = Self.asset("a", version: .distantFuture)
        _ = try await engine.analyze(currentID: "a", assets: assets)
        let refreshed = await printer.calls; XCTAssertEqual(refreshed, 7)
        let count = await engine.cachedCount; XCTAssertEqual(count, 3)
    }
    func testCandidateBoundAndCacheBound() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let assets = (0..<70).map { Self.asset(String(format: "%03d", $0), date: date.addingTimeInterval(Double($0))) }
        let selection = SimilarityCandidates.select(currentID: "035", assets: assets)
        XCTAssertEqual(selection.assets.count, 48); XCTAssertTrue(selection.truncated)
        let engine = SimilarityEngine(printer: Printer())
        _ = try await engine.analyze(currentID: "000", assets: assets)
        _ = try await engine.analyze(currentID: "069", assets: assets)
        let count = await engine.cachedCount; let bytes = await engine.cachedBytes
        XCTAssertLessThanOrEqual(count, 48); XCTAssertLessThanOrEqual(bytes, SimilarityEngine.byteLimit)
        let tomorrow = Self.asset("tomorrow", date: date.addingTimeInterval(86400))
        XCTAssertFalse(SimilarityCandidates.select(currentID: "000", assets: assets + [tomorrow]).assets.contains { $0.id == "tomorrow" })
    }
    func testCancelAndResumeCannotPublishOldResult() async throws {
        let printer = Printer(delayed: true); let model = SimilarityModel(engine: SimilarityEngine(printer: printer))
        model.start(currentID: "a", assets: [Self.asset("a"), Self.asset("b")])
        while await printer.calls == 0 { await Task.yield() }
        model.pause(); try await Task.sleep(for: .milliseconds(100)); XCTAssertEqual(model.state, .paused)
        model.start(currentID: "a", assets: [Self.asset("a"), Self.asset("b")])
        for _ in 0..<100 { if model.state != .analyzing { break }; try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(model.groups.map(\.assetIDs), [["a", "b"]])
    }
    #if !targetEnvironment(simulator)
    actor BundledPrinter: FeaturePrinting {
        nonisolated let version = "bundled-production-v1"
        let native = VisionFeaturePrinter()
        let images: [String: Data]
        init(images: [String: Data]) { self.images = images }
        func descriptor(for asset: PhotoAssetSnapshot) async throws -> Data {
            guard let data = images[asset.id] else { throw SimilarityFailure.unavailable }
            return try await native.descriptor(imageData: data)
        }
        func distance(_ lhs: Data, _ rhs: Data) async throws -> Float { try await native.distance(lhs, rhs) }
    }
    func testBundledVisionNegativeControl() async throws {
        var prints: [VNFeaturePrintObservation] = []
        for name in ["landscape", "landscape-copy", "portrait-smile", "portrait-frown", "square"] {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "jpg"))
            let request = VNGenerateImageFeaturePrintRequest()
            request.revision = VNGenerateImageFeaturePrintRequestRevision2
            request.usesCPUOnly = true
            try VNImageRequestHandler(url: url).perform([request])
            prints.append(try XCTUnwrap(request.results?.first))
        }
        var duplicate: Float = 0; var expression: Float = 0; var unrelated: Float = 0
        try prints[0].computeDistance(&duplicate, to: prints[1])
        try prints[2].computeDistance(&expression, to: prints[3])
        try prints[0].computeDistance(&unrelated, to: prints[4])
        print("BUNDLED_VISION", duplicate, expression, unrelated)
        XCTAssertLessThan(duplicate, 0.001); XCTAssertGreaterThan(expression, 0.12); XCTAssertGreaterThan(unrelated, 0.12)
    }
    func testBundledProductionVisionPipeline() async throws {
        let printer = VisionFeaturePrinter()
        var prints: [Data] = []
        var images: [String: Data] = [:]
        let names = ["landscape", "landscape-copy", "landscape-near", "portrait-smile", "portrait-frown", "square"]
        for name in names {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "jpg"))
            let data = try Data(contentsOf: url); images[name] = data
            prints.append(try await printer.descriptor(imageData: data))
        }
        let exact = try await printer.distance(prints[0], prints[1])
        let near = try await printer.distance(prints[0], prints[2])
        let expression = try await printer.distance(prints[3], prints[4])
        let unrelated = try await printer.distance(prints[0], prints[5])
        print("PRODUCTION_VISION", exact, near, expression, unrelated)
        XCTAssertLessThan(exact, 0.001)
        XCTAssertLessThan(near, SimilarityEngine.threshold)
        XCTAssertGreaterThan(expression, SimilarityEngine.threshold)
        XCTAssertGreaterThan(unrelated, SimilarityEngine.threshold)
        let engine = SimilarityEngine(printer: BundledPrinter(images: images))
        let report = try await engine.analyze(currentID: "landscape", assets: names.map { Self.asset($0) })
        XCTAssertEqual(report.groups.map(\.assetIDs), [["landscape", "landscape-copy", "landscape-near"]])
        XCTAssertEqual(report.unavailableCount, 0)
        let repeated = try await engine.analyze(currentID: "landscape", assets: names.map { Self.asset($0) })
        XCTAssertEqual(repeated, report)
    }
    #endif
    func testRealVisionPrintsOnAuthorizedGeneratedFixtures() async throws {
        let snapshot = await PhotoLibraryGateway().snapshot()
        XCTAssertTrue(snapshot.permission.canRead)
        var named: [String: String] = [:]
        PHAsset.fetchAssets(withLocalIdentifiers: snapshot.assets.map(\.id), options: nil).enumerateObjects { asset, _, _ in
            for resource in PHAssetResource.assetResources(for: asset) { named[resource.originalFilename] = asset.localIdentifier }
        }
        let printer = VisionFeaturePrinter(); var prints: [String: Data] = [:]
        for name in ["landscape.jpg", "landscape-copy.jpg", "landscape-near.jpg", "portrait-smile.jpg", "portrait-frown.jpg", "square.jpg"] {
            let id = try XCTUnwrap(named[name]); let asset = try XCTUnwrap(snapshot.assets.first { $0.id == id })
            do { prints[name] = try await printer.descriptor(for: asset) }
            catch SimilarityFailure.runtimeUnavailable {
                #if targetEnvironment(simulator)
                let engine = SimilarityEngine(printer: printer)
                do {
                    _ = try await engine.analyze(currentID: id, assets: snapshot.assets)
                    XCTFail("Unhealthy Vision must reject analysis")
                } catch SimilarityFailure.runtimeUnavailable { }
                let cached = await engine.cachedCount
                XCTAssertEqual(cached, 0)
                print("SIMULATOR_VISION_UNAVAILABLE: fail-closed path verified; physical quality gate remains mandatory")
                return
                #else
                throw SimilarityFailure.runtimeUnavailable
                #endif
            }
        }
        func distance(_ a: String, _ b: String) async throws -> Float {
            let result = try await printer.distance(try XCTUnwrap(prints[a]), try XCTUnwrap(prints[b]))
            print("VISION_DISTANCE \(a) / \(b): \(result)"); return result
        }
        let exact = try await distance("landscape.jpg", "landscape-copy.jpg")
        let near = try await distance("landscape.jpg", "landscape-near.jpg")
        let expression = try await distance("portrait-smile.jpg", "portrait-frown.jpg")
        let unrelated = try await distance("landscape.jpg", "square.jpg")
        XCTAssertLessThan(exact, 0.001)
        XCTAssertLessThan(near, SimilarityEngine.threshold)
        XCTAssertGreaterThan(expression, SimilarityEngine.threshold)
        XCTAssertGreaterThan(unrelated, SimilarityEngine.threshold)
    }
}
