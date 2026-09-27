import Foundation

enum LibraryPermission: String, Sendable, CaseIterable {
    case notDetermined, restricted, denied, limited, full, unknown
    var canRead: Bool { self == .limited || self == .full }
    var guidance: String {
        switch self {
        case .notDetermined: "允许访问照片，开始回顾你的时光。"
        case .restricted: "照片访问受到设备限制。"
        case .denied: "尚未获得照片权限，请在设置中允许访问。"
        case .limited: "仅回顾你选择的照片和视频。"
        case .full: "可以回顾已授权的照片和视频。"
        case .unknown: "暂时无法确认照片权限，请重试。"
        }
    }
}

struct PhotoAssetSnapshot: Identifiable, Sendable, Equatable {
    enum Kind: String, Sendable { case photo, video }
    let id: String
    let kind: Kind
    let creationDate: Date?
    let modificationDate: Date?
    let width: Int
    let height: Int
    let duration: Double
    let isFavorite: Bool
    let isLivePhoto: Bool
}

struct LibrarySnapshot: Sendable {
    let permission: LibraryPermission
    let assets: [PhotoAssetSnapshot]
    // Shared Albums can be excluded. iCloud Shared Photo Library membership
    // cannot be determined with the inspected public iOS26 SDK API.
    let sharedLibraryMembershipVerified: Bool
    var emptyMessage: String {
        guard permission.canRead else { return permission.guidance }
        return permission == .limited ? "所选范围内暂无可回顾内容。" : "已授权范围内暂无可回顾内容。"
    }
}
