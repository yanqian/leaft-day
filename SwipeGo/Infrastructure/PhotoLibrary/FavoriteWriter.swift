import Foundation
import Photos
import Synchronization

protocol FavoriteWriting: Sendable {
    func asset(id: String) async throws -> PhotoAssetSnapshot
    func setFavorite(id: String, value: Bool, expected: PhotoAssetSnapshot) async throws -> PhotoAssetSnapshot
}

enum FavoriteError: Error { case unavailable, permission, changed, busy, noUndo, cancelled }

actor NativeFavoriteWriter: FavoriteWriting {
    func asset(id: String) throws -> PhotoAssetSnapshot {
        guard PhotoLibraryGateway.permission(PHPhotoLibrary.authorizationStatus(for: .readWrite)).canRead else { throw FavoriteError.permission }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
              !asset.isHidden, asset.sourceType == .typeUserLibrary else { throw FavoriteError.unavailable }
        return PhotoAssetSnapshot(id: asset.localIdentifier, kind: asset.mediaType == .video ? .video : .photo,
            creationDate: asset.creationDate, modificationDate: asset.modificationDate,
            width: asset.pixelWidth, height: asset.pixelHeight, duration: asset.duration,
            isFavorite: asset.isFavorite, isLivePhoto: asset.mediaSubtypes.contains(.photoLive))
    }
    func setFavorite(id: String, value: Bool, expected: PhotoAssetSnapshot) async throws -> PhotoAssetSnapshot {
        guard try asset(id: id) == expected else { throw FavoriteError.changed }
        let submitted = Mutex(false)
        do { try await PHPhotoLibrary.shared().performChanges {
            // Recheck in the native change block; never apply an undo to a new target.
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
                  !asset.isHidden, asset.sourceType == .typeUserLibrary,
                  asset.isFavorite == expected.isFavorite,
                  asset.modificationDate == expected.modificationDate else { return }
            PHAssetChangeRequest(for: asset).isFavorite = value
            submitted.withLock { $0 = true }
        }
        } catch {
            let native = error as NSError
            if native.domain == PHPhotosErrorDomain && native.code == PHPhotosError.Code.userCancelled.rawValue { throw FavoriteError.cancelled }
            throw error
        }
        guard submitted.withLock({ $0 }) else { throw FavoriteError.changed }
        let result = try asset(id: id)
        guard result.isFavorite == value else { throw FavoriteError.changed }
        return result
    }
}
