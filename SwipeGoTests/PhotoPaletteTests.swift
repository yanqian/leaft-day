import XCTest
@testable import SwipeGo

@MainActor final class PhotoPaletteTests: XCTestCase {
    private func image(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            color.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }
    private func asset(_ id: String, version: Date? = nil, video: Bool = false) -> PhotoAssetSnapshot {
        .init(id: id, kind: video ? .video : .photo, creationDate: nil, modificationDate: version,
              width: 900, height: 600, duration: 0, isFavorite: false, isLivePhoto: false)
    }
    func testDistinctNaturalColorsAndDarkTextContrast() {
        let inputs = [UIColor.blue, .red, .green, .purple, .brown, .gray, .black, .white]
        let palettes = inputs.map { PhotoPalette.extract(from: image($0)) }
        XCTAssertNotEqual(palettes[0], palettes[1]); XCTAssertNotEqual(palettes[0], palettes[2])
        func luminance(_ values: [Double]) -> Double {
            zip(values, [0.2126, 0.7152, 0.0722]).reduce(0) { result, pair in
                result + (pair.0 <= 0.04045 ? pair.0 / 12.92 : pow((pair.0 + 0.055) / 1.055, 2.4)) * pair.1
            }
        }
        let text = luminance([0.20, 0.30, 0.31])
        for palette in palettes {
            XCTAssertEqual(palette.colors.count, 3)
            for c in palette.colors {
                XCTAssertGreaterThanOrEqual((luminance([c.red, c.green, c.blue]) + 0.05) / (text + 0.05), 4.5)
            }
        }
        XCTAssertEqual(palettes[6], .neutral); XCTAssertEqual(palettes[7], .neutral)
    }
    func testTransparentMalformedBoundedAndStableSamples() {
        XCTAssertEqual(PhotoPalette.extract(rgba: []), .neutral)
        XCTAssertEqual(PhotoPalette.extract(rgba: [4, 6, 9]), .neutral)
        XCTAssertEqual(PhotoPalette.extract(rgba: [0, 0, 0, 0]), .neutral)
        let blue: [UInt8] = [20, 100, 210, 255]
        let red: [UInt8] = [210, 50, 40, 255]
        let capped = Array(repeating: blue, count: 4096).flatMap { $0 }
        XCTAssertEqual(PhotoPalette.extract(rgba: capped + Array(repeating: red, count: 5000).flatMap { $0 }), PhotoPalette.extract(rgba: capped))
        XCTAssertEqual(PhotoPalette.extract(rgba: blue + red), PhotoPalette.extract(rgba: red + blue))
    }
    func testLocalOnlyStaleCallbacksAndVersionRefresh() {
        let transport = PhotoLoaderTests.Transport(); let model = PhotoPaletteModel(transport: transport)
        model.load(asset("a")); let stale = transport.callbacks.values.first!
        model.load(asset("b")); let current = transport.callbacks.first { !transport.cancelled.contains($0.key) }!.value
        current(.image(image(.blue))); let blue = model.palette
        stale(.image(image(.red))); XCTAssertEqual(model.palette, blue)
        model.load(asset("b", version: Date(timeIntervalSince1970: 42)))
        XCTAssertEqual(model.palette, .neutral)
        XCTAssertEqual(transport.keys.last?.version, Date(timeIntervalSince1970: 42))
        XCTAssertEqual(transport.networks, [false, false, false])
        XCTAssertTrue(transport.keys.allSatisfy { $0.pixelWidth <= 96 && $0.pixelHeight <= 96 })
    }
    func testFrozenDeletionPaletteOutlivesSourceAndCancels() {
        let transport = PhotoLoaderTests.Transport(); let model = PhotoPaletteModel(transport: transport)
        model.load(asset("to-delete")); let callback = transport.callbacks.values.first!
        callback(.image(image(.green))); let frozen = model.freeze()
        callback(.unavailable); callback(.image(image(.red)))
        model.load(asset("deleted")); model.use(image(.blue))
        XCTAssertEqual(model.palette, frozen); XCTAssertEqual(transport.keys.count, 1)
        XCTAssertEqual(transport.cancelled.count, 1)
        model.reset(); XCTAssertEqual(model.palette, .neutral); XCTAssertFalse(model.frozen)
        model.load(nil); model.load(asset("video", video: true)); XCTAssertEqual(transport.keys.count, 1)
    }
    func testCancelledAndDeinitializedModelsRejectOrCancelPendingWork() {
        let transport = PhotoLoaderTests.Transport(); var model: PhotoPaletteModel? = .init(transport: transport)
        model?.load(asset("a")); let callback = transport.callbacks.values.first!
        model?.cancel(); callback(.image(image(.red))); XCTAssertEqual(model?.palette, .neutral)
        model?.load(asset("b")); model = nil
        XCTAssertEqual(transport.cancelled.count, 2)
    }
}
