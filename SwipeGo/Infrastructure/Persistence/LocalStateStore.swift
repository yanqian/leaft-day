import Foundation
import SwiftData

actor LocalStateStore: ModelActor, LocalStateRepository {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    private var activeContext: ModelContext?
    private var context: ModelContext {
        if let activeContext { return activeContext }
        let fresh = ModelContext(modelContainer)
        fresh.autosaveEnabled = false
        activeContext = fresh
        return fresh
    }

    init(url: URL, allowsSave: Bool = true) throws {
        let schema = Schema(versionedSchema: IntentSchemaV1.self)
        let configuration = ModelConfiguration("UserIntent", schema: schema, url: url,
                                               allowsSave: allowsSave, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, migrationPlan: IntentMigrations.self,
                                           configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.modelContainer = container
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    private func transaction(_ mutation: () throws -> Void) throws {
        do {
            try mutation()
            try context.save()
        } catch {
            context.rollback()
            activeContext = nil // Failed saves can leave registered objects despite rollback.
            throw error
        }
    }

    func saveSession(_ value: SessionState) throws {
        guard !value.assetIDs.isEmpty, value.assetIDs.allSatisfy({ !$0.isEmpty }),
              Set(value.assetIDs).count == value.assetIDs.count,
              value.assetIDs.indices.contains(value.cursor) else { throw LocalStateError.invalidSession }
        let id = value.id
        let payload = try JSONEncoder().encode(value)
        try transaction {
            let rows = try context.fetch(FetchDescriptor<IntentSchemaV1.Session>(predicate: #Predicate { $0.id == id }))
            if let row = rows.first { row.payload = payload }
            else { context.insert(IntentSchemaV1.Session(id: id, payload: payload)) }
        }
    }

    func session(id: UUID) throws -> SessionState? {
        let rows = try context.fetch(FetchDescriptor<IntentSchemaV1.Session>(predicate: #Predicate { $0.id == id }))
        return try rows.first.map { try JSONDecoder().decode(SessionState.self, from: $0.payload) }
    }

    func markPending(_ value: PendingIntent) throws {
        guard !value.assetID.isEmpty else { throw LocalStateError.invalidAsset }
        let assetID = value.assetID
        let payload = try JSONEncoder().encode(value)
        try transaction {
            let rows = try context.fetch(FetchDescriptor<IntentSchemaV1.Pending>(predicate: #Predicate { $0.assetID == assetID }))
            // Repeated marks preserve the original user intent, including source group/time.
            if rows.isEmpty { context.insert(IntentSchemaV1.Pending(assetID: assetID, payload: payload)) }
        }
    }

    func pending() throws -> [PendingIntent] {
        try context.fetch(FetchDescriptor<IntentSchemaV1.Pending>())
            .map { try JSONDecoder().decode(PendingIntent.self, from: $0.payload) }
            .sorted { ($0.markedAt, $0.assetID) < ($1.markedAt, $1.assetID) }
    }

    func removePending(assetID: String) throws {
        try transaction {
            let rows = try context.fetch(FetchDescriptor<IntentSchemaV1.Pending>(predicate: #Predicate { $0.assetID == assetID }))
            for row in rows { context.delete(row) }
        }
    }

    func saveOperation(_ value: OperationState) throws {
        guard !value.targetIDs.isEmpty, value.targetIDs.allSatisfy({ !$0.isEmpty }),
              Set(value.targetIDs).count == value.targetIDs.count else { throw LocalStateError.invalidOperation }
        let id = value.id
        let payload = try JSONEncoder().encode(value)
        try transaction {
            let rows = try context.fetch(FetchDescriptor<IntentSchemaV1.Operation>(predicate: #Predicate { $0.id == id }))
            if let row = rows.first { row.payload = payload }
            else { context.insert(IntentSchemaV1.Operation(id: id, payload: payload)) }
        }
    }

    func operations() throws -> [OperationState] {
        try context.fetch(FetchDescriptor<IntentSchemaV1.Operation>())
            .map { try JSONDecoder().decode(OperationState.self, from: $0.payload) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
