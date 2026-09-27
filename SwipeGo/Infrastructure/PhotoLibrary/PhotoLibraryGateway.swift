import Foundation
import Photos

actor PhotoLibraryGateway {
    static func permission(_ status: PHAuthorizationStatus) -> LibraryPermission {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .limited: .limited
        case .authorized: .full
        @unknown default: .unknown
        }
    }

    func requestAccess() async -> LibraryPermission {
        Self.permission(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    func snapshot() -> LibrarySnapshot {
        let permission = Self.permission(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        guard permission.canRead else {
            return LibrarySnapshot(permission: permission, assets: [], sharedLibraryMembershipVerified: false)
        }
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = .typeUserLibrary
        options.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PhotoAssetSnapshot] = []
        result.enumerateObjects { asset, _, _ in
            guard !asset.isHidden, asset.sourceType == .typeUserLibrary else { return }
            assets.append(PhotoAssetSnapshot(id: asset.localIdentifier,
                kind: asset.mediaType == .video ? .video : .photo,
                creationDate: asset.creationDate, modificationDate: asset.modificationDate,
                width: asset.pixelWidth, height: asset.pixelHeight, duration: asset.duration,
                isFavorite: asset.isFavorite, isLivePhoto: asset.mediaSubtypes.contains(.photoLive)))
        }
        assets.sort {
            if $0.creationDate != $1.creationDate { return ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            return $0.id < $1.id
        }
        // A permission change during fetch invalidates this snapshot; refetch later.
        let after = Self.permission(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        guard after == permission else {
            return LibrarySnapshot(permission: after, assets: [], sharedLibraryMembershipVerified: false)
        }
        return LibrarySnapshot(permission: permission, assets: assets, sharedLibraryMembershipVerified: false)
    }
}
