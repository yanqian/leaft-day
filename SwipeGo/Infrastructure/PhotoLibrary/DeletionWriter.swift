import Foundation
import Photos
import Synchronization

enum NativePhotoFacts {
    static func scope() -> PhotoAccessScope {
        let permission = PhotoLibraryGateway.permission(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        var ids: [String] = []
        if permission == .limited {
            PHAsset.fetchAssets(with: nil).enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
        }
        return PhotoAccessScope(permission: permission, limitedIDs: ids.sorted())
    }
    static func snapshot(_ asset: PHAsset) -> PhotoAssetSnapshot? {
        guard !asset.isHidden, asset.sourceType == .typeUserLibrary,
              asset.mediaType == .image || asset.mediaType == .video else { return nil }
        return PhotoAssetSnapshot(id: asset.localIdentifier, kind: asset.mediaType == .video ? .video : .photo,
            creationDate: asset.creationDate, modificationDate: asset.modificationDate,
            width: asset.pixelWidth, height: asset.pixelHeight, duration: asset.duration,
            isFavorite: asset.isFavorite, isLivePhoto: asset.mediaSubtypes.contains(.photoLive))
    }
}

actor NativeDeletionWriter: DeletionWriting {
    func accessScope() -> PhotoAccessScope { NativePhotoFacts.scope() }
    func asset(id: String) throws -> PhotoAssetSnapshot {
        guard NativePhotoFacts.scope().permission.canRead,
              let native = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
              let snapshot = NativePhotoFacts.snapshot(native) else { throw DeletionError.changed }
        return snapshot
    }
    func delete(_ frozen: FrozenDeletion) async throws {
        let submitted = Mutex(false)
        do {
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                guard frozen.scope.permission.canRead, NativePhotoFacts.scope() == frozen.scope else { return }
                var targets: [PHAsset] = []
                for expected in frozen.targets + frozen.keepers {
                    guard let native = PHAsset.fetchAssets(withLocalIdentifiers: [expected.id], options: nil).firstObject,
                          NativePhotoFacts.snapshot(native) == expected else { return }
                    if frozen.targets.contains(where: { $0.id == expected.id }) { targets.append(native) }
                }
                guard !targets.isEmpty, NativePhotoFacts.scope() == frozen.scope else { return }
                PHAssetChangeRequest.deleteAssets(targets as NSArray)
                submitted.withLock { $0 = true }
            }
        } catch {
            let native = error as NSError
            if native.domain == PHPhotosErrorDomain && native.code == PHPhotosError.Code.userCancelled.rawValue { throw DeletionError.cancelled }
            throw DeletionError.unknown
        }
        guard submitted.withLock({ $0 }) else { throw DeletionError.changed }
    }
}
