import XCTest
@testable import SwipeGo

@MainActor final class DeviceScopeTests: XCTestCase {
    func testFixtureSessionCannotExpandOnNativeLibraryRefresh() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let session = ReviewSession(store: try LocalStateStore(url: root.appendingPathComponent("Intent.store")), assetScope: ["generated"])
        let all = [FavoriteTests.snapshot("personal"), FavoriteTests.snapshot("generated")]
        session.updateLibrary(LibrarySnapshot(permission: .full, assets: all, sharedLibraryMembershipVerified: false))
        XCTAssertEqual(session.snapshot.assets.map(\.id), ["generated"])
        do { try await session.start(ReviewSegment(assetIDs: ["personal"], start: .distantPast, end: .distantPast)); XCTFail() } catch ReviewSessionError.unavailable { }
        try await session.start(ReviewSegment(assetIDs: ["generated"], start: .distantPast, end: .distantPast))
        session.updateLibrary(LibrarySnapshot(permission: .limited, assets: [all[0]], sharedLibraryMembershipVerified: false))
        XCTAssertTrue(session.snapshot.assets.isEmpty)
        guard case .unavailable = session.current else { return XCTFail() }
        XCTAssertEqual(session.state?.assetIDs, ["generated"])
    }
}
