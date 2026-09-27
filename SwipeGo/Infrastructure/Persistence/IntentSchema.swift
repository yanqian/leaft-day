import Foundation
import SwiftData

enum IntentSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Session.self, Pending.self, Operation.self] }

    @Model final class Session {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(id: UUID, payload: Data) { self.id = id; self.payload = payload }
    }
    @Model final class Pending {
        @Attribute(.unique) var assetID: String
        var payload: Data
        init(assetID: String, payload: Data) { self.assetID = assetID; self.payload = payload }
    }
    @Model final class Operation {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(id: UUID, payload: Data) { self.id = id; self.payload = payload }
    }
}

enum IntentMigrations: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [IntentSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// Durable user intent lives in Application Support. Rebuildable media and Vision
// cache belong in Caches, never in this schema or any cleanup of this store.
struct LocalStoragePaths: Sendable {
    let intentStore: URL
    let cacheDirectory: URL
    static func application() throws -> Self {
        let fm = FileManager.default
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("SwipeGo", isDirectory: true)
        let cache = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("SwipeGoMedia", isDirectory: true)
        try fm.createDirectory(at: support, withIntermediateDirectories: true)
        try fm.createDirectory(at: cache, withIntermediateDirectories: true)
        return Self(intentStore: support.appendingPathComponent("Intent.store"), cacheDirectory: cache)
    }
}
