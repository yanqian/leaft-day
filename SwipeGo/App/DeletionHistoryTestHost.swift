#if DEBUG
import SwiftUI

/// Isolated local records only; this host never accesses or deletes Photos assets.
struct DeletionHistoryTestHost: View {
    @State private var store: LocalStateStore?
    @State private var shown = false
    @State private var failRead = true
    @State private var failure: String?
    var body: some View {
        VStack {
            Button("打开记录") { shown = true }.disabled(store == nil)
            if let failure { Text(failure) }
        }.sheet(isPresented: $shown) {
            if let store {
                if ProcessInfo.processInfo.arguments.contains("--history-read-error") {
                    DeletionHistoryView(read: {
                        if failRead { failRead = false; throw LocalStateError.readOnly }
                        return try store.operations()
                    }).presentationBackground(.clear)
                } else { DeletionHistoryView(store: store).presentationBackground(.clear) }
            }
        }.task {
            do {
                let local = try LocalStateStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".store"))
                if !ProcessInfo.processInfo.arguments.contains("--history-empty") {
                    let outcomes: [OperationState.DeletionOutcome] = [.success, .cancelled, .notSubmitted, .unknown]
                    for (index, outcome) in outcomes.enumerated() {
                        try local.saveOperation(OperationState(deletionOutcome: outcome, id: UUID(), kind: .deletion,
                            targetIDs: (0..<(index + 2)).map { "history-fixture-\($0)" },
                            phase: outcome == .success ? .succeeded : .needsReview,
                            updatedAt: Date(timeIntervalSince1970: 1_790_675_000 - Double(index * 3600))))
                    }
                }
                store = local; shown = true
            } catch { failure = "历史测试准备失败：\(error)" }
        }
    }
}
#endif
