import XCTest
import Photos
@testable import SwipeGo

@MainActor
final class PhotoLibraryTests: XCTestCase {
    func testPermissionMappingAndLimitedEmptyScope() {
        XCTAssertEqual(PhotoLibraryGateway.permission(.notDetermined), .notDetermined)
        XCTAssertEqual(PhotoLibraryGateway.permission(.restricted), .restricted)
        XCTAssertEqual(PhotoLibraryGateway.permission(.denied), .denied)
        XCTAssertEqual(PhotoLibraryGateway.permission(.limited), .limited)
        XCTAssertEqual(PhotoLibraryGateway.permission(.authorized), .full)
        let limited = LibrarySnapshot(permission: .limited, assets: [], sharedLibraryMembershipVerified: false)
        XCTAssertTrue(limited.emptyMessage.contains("所选范围"))
        XCTAssertFalse(limited.sharedLibraryMembershipVerified)
    }
    func testRealSystemQueryRespectsCurrentAuthorization() async {
        let expected = PhotoLibraryGateway.permission(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        let snapshot = await PhotoLibraryGateway().snapshot()
        XCTAssertEqual(snapshot.permission, expected)
        if !expected.canRead { XCTAssertTrue(snapshot.assets.isEmpty) }
        XCTAssertEqual(Set(snapshot.assets.map(\.id)).count, snapshot.assets.count)
        XCTAssertTrue(snapshot.assets.allSatisfy { $0.width > 0 && $0.height > 0 })
        print("REAL_PHOTOS_STATE=\(snapshot.permission.rawValue) COUNT=\(snapshot.assets.count) HOST=\(Bundle.main.bundleIdentifier ?? "unknown")")
    }
}
