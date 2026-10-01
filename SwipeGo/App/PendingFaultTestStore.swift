#if DEBUG
import Foundation

/// Fault injection only for the isolated generated-fixture UI host. It fails
/// one precise local write, forwarding all other work to the real disk store.
@MainActor final class PendingFaultTestStore: LocalStateRepository {
    enum Fault { case undo, position }
    let base: LocalStateStore
    let fault: Fault
    private var armed = false
    private var hasArmed = false
    init(base: LocalStateStore, fault: Fault) { self.base = base; self.fault = fault }
    func armOnce() { if !hasArmed { armed = true; hasArmed = true } }
    private func failIfArmed(_ expected: Fault) throws {
        if armed && fault == expected { armed = false; throw LocalStateError.readOnly }
    }
    func saveSession(_ value: SessionState) throws { try failIfArmed(.position); try base.saveSession(value) }
    func latestSession() throws -> SessionState? { try base.latestSession() }
    func session(id: UUID) throws -> SessionState? { try base.session(id: id) }
    func markPending(_ value: PendingIntent) throws { try base.markPending(value) }
    func saveComparison(_ values: [PendingIntent], keeping: [String]) throws { try base.saveComparison(values, keeping: keeping) }
    func pending() throws -> [PendingIntent] { try base.pending() }
    func removePending(assetID: String) throws { try failIfArmed(.undo); try base.removePending(assetID: assetID) }
    func removePending(ifMatching expected: PendingIntent) throws { try base.removePending(ifMatching: expected) }
    func saveOperation(_ value: OperationState) throws { try base.saveOperation(value) }
    func prepareDeletion(_ frozen: FrozenDeletion) throws -> OperationState { try base.prepareDeletion(frozen) }
    func completeDeletion(_ operation: OperationState) throws { try base.completeDeletion(operation) }
    func replaceOperation(ifMatching expected: OperationState, with next: OperationState) throws -> Bool { try base.replaceOperation(ifMatching: expected, with: next) }
    func operations() throws -> [OperationState] { try base.operations() }
}
#endif
