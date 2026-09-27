import Foundation
import UIKit
import Photos
import SwiftUI

struct PhotoRequestKey: Hashable, Sendable {
    let assetID: String
    let version: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    init(assetID: String, version: Date? = nil, width: Int, height: Int) {
        self.assetID = assetID; self.version = version
        self.pixelWidth = max(1, min(width, 4096)); self.pixelHeight = max(1, min(height, 4096))
    }
}

enum PhotoLoadEvent {
    case progress(Double)
    case image(UIImage)
    case needsDownload
    case offline
    case unavailable
    case failed(String)
}

@MainActor
protocol PhotoTransport: AnyObject {
    func request(_ key: PhotoRequestKey, network: Bool, receive: @escaping @MainActor (PhotoLoadEvent) -> Void) -> UUID
    func cancel(_ token: UUID)
}

@MainActor
final class NativePhotoTransport: PhotoTransport {
    private let manager = PHImageManager()
    private var requests: [UUID: PHImageRequestID] = [:]
    isolated deinit { for request in requests.values { manager.cancelImageRequest(request) } }

    func request(_ key: PhotoRequestKey, network: Bool, receive: @escaping @MainActor (PhotoLoadEvent) -> Void) -> UUID {
        let token = UUID()
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [key.assetID], options: nil).firstObject,
              asset.mediaType == .image, !asset.isHidden, asset.sourceType == .typeUserLibrary else {
            receive(.unavailable); return token
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = network
        options.progressHandler = { progress, _, _, _ in
            Task { @MainActor [weak self] in
                guard self?.requests[token] != nil else { return }
                receive(.progress(min(1, max(0, progress))))
            }
        }
        let requestID = manager.requestImage(for: asset,
            targetSize: CGSize(width: key.pixelWidth, height: key.pixelHeight), contentMode: .aspectFit, options: options) { image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
            let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let cloud = (info?[PHImageResultIsInCloudKey] as? Bool) == true
            let error = info?[PHImageErrorKey] as? NSError
            let offline = error?.domain == NSURLErrorDomain && error?.code == NSURLErrorNotConnectedToInternet
            let message = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, requests[token] != nil else { return }
                if cancelled { requests.removeValue(forKey: token); return }
                if degraded { return }
                requests.removeValue(forKey: token)
                if let image { receive(.image(image)) }
                else if offline { receive(.offline) }
                else if cloud && !network { receive(.needsDownload) }
                else if let message { receive(.failed(message)) }
                else { receive(.unavailable) }
            }
        }
        requests[token] = requestID
        return token
    }

    func cancel(_ token: UUID) {
        if let request = requests.removeValue(forKey: token) { manager.cancelImageRequest(request) }
    }
}

@MainActor
final class PhotoMemoryCache {
    private struct Entry { let image: UIImage; let bytes: Int; var access: UInt64 }
    private var entries: [PhotoRequestKey: Entry] = [:]
    private var clock: UInt64 = 0
    let byteLimit: Int
    let countLimit: Int
    private(set) var bytes = 0
    var count: Int { entries.count }
    init(byteLimit: Int = 32 * 1024 * 1024, countLimit: Int = 12) {
        self.byteLimit = max(0, byteLimit); self.countLimit = max(0, countLimit)
    }
    func image(for key: PhotoRequestKey) -> UIImage? {
        guard var entry = entries[key] else { return nil }
        clock &+= 1; entry.access = clock; entries[key] = entry; return entry.image
    }
    func insert(_ image: UIImage, for key: PhotoRequestKey) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        if let old = entries.removeValue(forKey: key) { bytes -= old.bytes }
        guard cost <= byteLimit, countLimit > 0 else { return }
        while bytes + cost > byteLimit || entries.count >= countLimit {
            guard let oldest = entries.min(by: { $0.value.access < $1.value.access })?.key else { break }
            bytes -= entries.removeValue(forKey: oldest)!.bytes
        }
        clock &+= 1; entries[key] = Entry(image: image, bytes: cost, access: clock); bytes += cost
    }
    func invalidate(assetID: String) {
        for key in entries.keys.filter({ $0.assetID == assetID }) { bytes -= entries.removeValue(forKey: key)!.bytes }
    }
    func removeAll() { entries.removeAll(); bytes = 0 }
}

@MainActor @Observable
final class PhotoLoader {
    enum State { case idle, loading(Double?), ready(UIImage), needsDownload, offline, unavailable, failed(String) }
    private(set) var state: State = .idle
    private(set) var current: PhotoRequestKey?
    private var generation = UUID()
    @ObservationIgnored private var requests: [UUID] = []
    @ObservationIgnored private let transport: any PhotoTransport
    @ObservationIgnored let cache: PhotoMemoryCache
    init(transport: any PhotoTransport = NativePhotoTransport(), cache: PhotoMemoryCache = PhotoMemoryCache()) {
        self.transport = transport; self.cache = cache
    }
    func load(_ key: PhotoRequestKey, neighbors: [PhotoRequestKey] = [], network: Bool = true) {
        cancel()
        current = key
        let requestGeneration = generation
        if let image = cache.image(for: key) { state = .ready(image) }
        else {
            state = .loading(nil)
            let token = transport.request(key, network: network) { [weak self] event in
                guard let self, generation == requestGeneration, current == key else { return }
                switch event {
                case .image(let image): cache.insert(image, for: key); state = .ready(image)
                case .progress(let value): state = .loading(value)
                case .needsDownload: state = .needsDownload
                case .offline: state = .offline
                case .unavailable: state = .unavailable
                case .failed(let message): state = .failed(message)
                }
            }
            requests.append(token)
        }
        var seen: Set<PhotoRequestKey> = [key]
        for neighbor in neighbors.filter({ seen.insert($0).inserted }).prefix(2) {
            guard cache.image(for: neighbor) == nil else { continue }
            // Prefetch never downloads iCloud originals just because an item is nearby.
            requests.append(transport.request(neighbor, network: false) { [weak self] event in
                guard let self, generation == requestGeneration else { return }
                if case .image(let image) = event { cache.insert(image, for: neighbor) }
            })
        }
    }
    isolated deinit { for token in requests { transport.cancel(token) } }
    func retry() { if let current { load(current, network: true) } }
    func cancel() {
        generation = UUID()
        for token in requests { transport.cancel(token) }
        requests.removeAll(); current = nil; state = .idle
    }
    func releaseMemory() { cancel(); cache.removeAll() }
}

struct PhotoContentView: View {
    let image: UIImage
    var body: some View { Image(uiImage: image).resizable().scaledToFit().background(.black) }
}
