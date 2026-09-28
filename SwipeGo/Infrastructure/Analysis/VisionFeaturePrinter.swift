import Foundation
import Photos
import UIKit
import Vision
import CoreML
import Synchronization

protocol FeaturePrinting: Sendable {
    var version: String { get }
    func descriptor(for asset: PhotoAssetSnapshot) async throws -> Data
    func distance(_ lhs: Data, _ rhs: Data) async throws -> Float
}

enum SimilarityFailure: Error { case unavailable, changed, invalidPrint, runtimeUnavailable }

// All native image/feature work is serialized on this actor, away from the UI actor.
actor VisionFeaturePrinter: FeaturePrinting {
    private var healthy: Bool?
    nonisolated let version = "vision-r2-fill512-v1-" + ProcessInfo.processInfo.operatingSystemVersionString
    func descriptor(for expected: PhotoAssetSnapshot) throws -> Data {
        try Task.checkCancellation()
        try verifyRuntime()
        guard PhotoLibraryGateway.permission(PHPhotoLibrary.authorizationStatus(for: .readWrite)).canRead,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [expected.id], options: nil).firstObject,
              !asset.isHidden, asset.sourceType == .typeUserLibrary, asset.mediaType == .image,
              asset.modificationDate == expected.modificationDate else { throw SimilarityFailure.unavailable }
        let options = PHImageRequestOptions()
        options.isSynchronous = true; options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat; options.resizeMode = .exact
        let received = Mutex<UIImage?>(nil)
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 512, height: 512), contentMode: .aspectFit, options: options) { image, info in
            if (info?[PHImageResultIsDegradedKey] as? Bool) != true { received.withLock { $0 = image } }
        }
        try Task.checkCancellation()
        guard let image = received.withLock({ $0 }) else { throw SimilarityFailure.unavailable }
        let result = try descriptor(image: image)
        try Task.checkCancellation()
        guard let latest = PHAsset.fetchAssets(withLocalIdentifiers: [expected.id], options: nil).firstObject,
              latest.modificationDate == expected.modificationDate else { throw SimilarityFailure.changed }
        return result
    }
    // The same normalization and archive path can be verified using bundled public fixtures.
    func descriptor(imageData: Data) throws -> Data {
        try Task.checkCancellation()
        try verifyRuntime()
        guard let image = UIImage(data: imageData) else { throw SimilarityFailure.invalidPrint }
        return try descriptor(image: image)
    }
    private func descriptor(image: UIImage) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else { throw SimilarityFailure.unavailable }
        let factor = min(512 / image.size.width, 512 / image.size.height, 1)
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true; format.preferredRange = .standard
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let encodedImage = normalized.pngData() else { throw SimilarityFailure.invalidPrint }
        let result = try featurePrint(encodedImage)
        try Task.checkCancellation()
        return try NSKeyedArchiver.archivedData(withRootObject: result, requiringSecureCoding: true)
    }
    private func featurePrint(_ data: Data) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest(); request.revision = VNGenerateImageFeaturePrintRequestRevision2
        request.imageCropAndScaleOption = .scaleFill
        for (stage, devices) in try request.supportedComputeStageDevices {
            guard let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) else { throw SimilarityFailure.runtimeUnavailable }
            request.setComputeDevice(cpu, for: stage)
        }
        try VNImageRequestHandler(data: data, options: [:]).perform([request])
        guard let result = request.results?.first else { throw SimilarityFailure.invalidPrint }
        return result
    }
    // Reject a runtime that returns indistinguishable features for contrasting controls.
    // This is a capability check, not calibration of user-photo quality or duplicate probability.
    private func verifyRuntime() throws {
        if let healthy { guard healthy else { throw SimilarityFailure.runtimeUnavailable }; return }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.preferredRange = .standard
        func control(_ stripes: Bool) throws -> Data {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { context in
                (stripes ? UIColor.blue : UIColor.red).setFill(); context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
                if stripes {
                    UIColor.yellow.setFill()
                    for x in stride(from: 0, to: 256, by: 32) { context.fill(CGRect(x: x, y: 0, width: 16, height: 256)) }
                } else {
                    UIColor.white.setFill(); context.cgContext.fillEllipse(in: CGRect(x: 40, y: 40, width: 176, height: 176))
                }
            }
            guard let data = image.pngData() else { throw SimilarityFailure.invalidPrint }; return data
        }
        do {
            let a = try control(false); let b = try control(true)
            let first = try featurePrint(a); let repeatPrint = try featurePrint(a); let contrast = try featurePrint(b)
            var repeatDistance: Float = 0; var contrastDistance: Float = 0
            try first.computeDistance(&repeatDistance, to: repeatPrint); try first.computeDistance(&contrastDistance, to: contrast)
            healthy = repeatDistance.isFinite && contrastDistance.isFinite && repeatDistance < 0.005 && contrastDistance > 0.12
        } catch { healthy = false; throw SimilarityFailure.runtimeUnavailable }
        guard healthy == true else { throw SimilarityFailure.runtimeUnavailable }
    }
    func distance(_ lhs: Data, _ rhs: Data) throws -> Float {
        try Task.checkCancellation()
        guard let left = try NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: lhs),
              let right = try NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: rhs) else { throw SimilarityFailure.invalidPrint }
        var distance: Float = 0
        try left.computeDistance(&distance, to: right)
        guard distance.isFinite else { throw SimilarityFailure.invalidPrint }
        return distance
    }
}
