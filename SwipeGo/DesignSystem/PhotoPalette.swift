import SwiftUI
import UIKit

/// A palette contains colors only. It can safely outlive the photo that produced it.
struct PhotoPalette: Equatable, Sendable {
    struct RGB: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        var color: Color { Color(red: red, green: green, blue: blue) }
        var token: String { [red, green, blue].map { String(format: "%02x", Int(($0 * 255).rounded())) }.joined() }
    }
    let colors: [RGB]
    static let neutral = PhotoPalette(colors: [
        RGB(red: 0.84, green: 0.91, blue: 0.94),
        RGB(red: 0.87, green: 0.94, blue: 0.89),
        RGB(red: 0.97, green: 0.94, blue: 0.88)
    ])
    var token: String { colors.map(\.token).joined(separator: "-") }

    /// Sampling is bounded independently of source dimensions; sRGB removes source
    /// color-space differences. Transparent pixels and near-black padding are ignored.
    static func extract(from image: UIImage) -> PhotoPalette {
        guard let cgImage = image.cgImage else { return .neutral }
        let side = 64
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return .neutral }
        return extract(rgba: pixels)
    }

    static func extract(rgba: [UInt8]) -> PhotoPalette {
        struct Bucket { var count = 0; var sums = [Double](repeating: 0, count: 3) }
        var buckets: [Int: Bucket] = [:]
        for index in stride(from: 0, to: min(rgba.count - rgba.count % 4, 64 * 64 * 4), by: 4) {
            let alpha = Double(rgba[index + 3]) / 255
            guard alpha >= 0.8 else { continue }
            let rgb = (0..<3).map { min(255, Double(rgba[index + $0]) / alpha) }
            let light = rgb.reduce(0, +) / 3
            guard light >= 24 && light <= 244 else { continue }
            let key = (Int(rgb[0]) / 32) * 64 + (Int(rgb[1]) / 32) * 8 + Int(rgb[2]) / 32
            var bucket = buckets[key, default: Bucket()]; bucket.count += 1
            for channel in 0..<3 { bucket.sums[channel] += rgb[channel] }
            buckets[key] = bucket
        }
        let candidates = buckets.sorted {
            $0.value.count == $1.value.count ? $0.key < $1.key : $0.value.count > $1.value.count
        }.map { entry in entry.value.sums.map { $0 / Double(entry.value.count) } }
        var chosen: [[Double]] = []
        for candidate in candidates {
            if chosen.allSatisfy({ prior in zip(prior, candidate).reduce(0) { $0 + pow($1.0 - $1.1, 2) } > 65 * 65 }) {
                chosen.append(candidate)
            }
            if chosen.count == 3 { break }
        }
        guard let first = chosen.first else { return .neutral }
        while chosen.count < 3 { chosen.append(first) }
        let colors = chosen.enumerated().map { index, rgb in
            let luminance = rgb.reduce(0, +) / 3
            let white = [0.70, 0.76, 0.83][index]
            let values = rgb.map { (($0 * 0.7 + luminance * 0.3) / 255) * (1 - white) + white }
            return RGB(red: values[0], green: values[1], blue: values[2])
        }
        return PhotoPalette(colors: colors)
    }
}

/// Uses one local thumbnail, keeps no UIImage/cache, and rejects late callbacks.
@MainActor @Observable final class PhotoPaletteModel {
    private(set) var palette: PhotoPalette = .neutral
    private(set) var frozen = false
    @ObservationIgnored private let transport: any PhotoTransport
    @ObservationIgnored private var request: UUID?
    @ObservationIgnored private var generation = UUID()
    init(transport: any PhotoTransport = NativePhotoTransport()) { self.transport = transport }
    func load(_ asset: PhotoAssetSnapshot?) {
        guard !frozen else { return }
        cancel(); palette = .neutral
        guard let asset, asset.kind == .photo else { return }
        let expected = generation
        request = transport.request(.init(assetID: asset.id, version: asset.modificationDate, width: 96, height: 96), network: false) { [weak self] event in
            guard let self, generation == expected, !frozen else { return }
            if case .image(let image) = event { palette = PhotoPalette.extract(from: image) }
        }
    }
    func use(_ image: UIImage?) {
        guard !frozen else { return }
        cancel(); palette = image.map { PhotoPalette.extract(from: $0) } ?? .neutral
    }
    @discardableResult func freeze() -> PhotoPalette { cancel(); frozen = true; return palette }
    func reset() { cancel(); frozen = false; palette = .neutral }
    func cancel() {
        generation = UUID()
        if let request { transport.cancel(request) }
        request = nil
    }
    isolated deinit { if let request { transport.cancel(request) } }
}
