import Foundation
import Observation

@MainActor @Observable final class SimilarityModel {
    enum State: Equatable { case idle, analyzing, ready(SimilarityReport), paused, failed }
    private(set) var state: State = .idle
    @ObservationIgnored private let engine: SimilarityEngine
    @ObservationIgnored private var task: Task<Void, Never>?
    private var generation = UUID()
    init(engine: SimilarityEngine = SimilarityEngine()) { self.engine = engine }
    func start(currentID: String?, assets: [PhotoAssetSnapshot]) {
        pause()
        guard let currentID else { state = .idle; return }
        let token = UUID(); generation = token; state = .analyzing
        task = Task {
            do {
                let report = try await engine.analyze(currentID: currentID, assets: assets)
                guard generation == token, !Task.isCancelled else { return }; state = .ready(report)
            } catch is CancellationError { }
            catch { if generation == token { state = .failed } }
        }
    }
    func pause() { generation = UUID(); task?.cancel(); task = nil; state = .paused }
    var groups: [SimilarityGroup] { if case .ready(let report) = state { report.groups } else { [] } }
    isolated deinit { task?.cancel() }
}
