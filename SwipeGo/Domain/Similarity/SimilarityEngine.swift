import Foundation

struct SimilarityGroup: Sendable, Equatable, Identifiable {
    let assetIDs: [String]
    var id: String { assetIDs.joined(separator: "|") }
}
struct SimilarityReport: Sendable, Equatable {
    var groups: [SimilarityGroup]
    var candidateCount: Int
    var unavailableCount: Int
    var truncated: Bool
}
struct SimilarityCandidates {
    static let limit = 48
    static func select(currentID: String, assets: [PhotoAssetSnapshot]) -> (assets: [PhotoAssetSnapshot], truncated: Bool) {
        guard let current = assets.first(where: { $0.id == currentID }), let date = current.creationDate else { return ([], false) }
        let timeline = ReviewTimeline(); let segments = timeline.segments(in: assets)
        guard let index = segments.firstIndex(where: { $0.assetIDs.contains(currentID) }) else { return ([], false) }
        let ids = Set([index - 1, index, index + 1].filter { segments.indices.contains($0) }.flatMap { segments[$0].assetIDs })
        let candidates = assets.filter { $0.kind == .photo && ids.contains($0.id) && $0.creationDate.map { timeline.calendar.isDate($0, inSameDayAs: date) } == true }
            .sorted {
                let l = abs(($0.creationDate ?? date).timeIntervalSince(date)); let r = abs(($1.creationDate ?? date).timeIntervalSince(date))
                return l == r ? $0.id < $1.id : l < r
            }
        return (Array(candidates.prefix(limit)).sorted { ($0.creationDate ?? date, $0.id) < ($1.creationDate ?? date, $1.id) }, candidates.count > limit)
    }
}

actor SimilarityEngine {
    struct Key: Hashable { let id: String; let modified: Date?; let width: Int; let height: Int; let algorithm: String }
    static let threshold: Float = 0.12
    static let byteLimit = 2 * 1024 * 1024
    private let printer: any FeaturePrinting
    private var cache: [Key: Data] = [:]
    private var order: [Key] = []
    var cachedCount: Int { cache.count }
    var cachedBytes: Int { cache.values.reduce(0) { $0 + $1.count } }
    init(printer: any FeaturePrinting = VisionFeaturePrinter()) { self.printer = printer }
    func invalidate(assets: [PhotoAssetSnapshot]) {
        let valid = Set(assets.map { Key(id: $0.id, modified: $0.modificationDate, width: $0.width, height: $0.height, algorithm: printer.version) })
        cache = cache.filter { valid.contains($0.key) }; order.removeAll { cache[$0] == nil }
    }
    func analyze(currentID: String, assets: [PhotoAssetSnapshot]) async throws -> SimilarityReport {
        invalidate(assets: assets)
        let selected = SimilarityCandidates.select(currentID: currentID, assets: assets)
        var ready: [(PhotoAssetSnapshot, Data)] = []; var unavailable = 0
        for asset in selected.assets {
            try Task.checkCancellation()
            let key = Key(id: asset.id, modified: asset.modificationDate, width: asset.width, height: asset.height, algorithm: printer.version)
            do {
                let data: Data
                if let saved = cache[key] { data = saved }
                else { data = try await printer.descriptor(for: asset) }
                try Task.checkCancellation()
                if data.count <= Self.byteLimit {
                    cache[key] = data; order.removeAll { $0 == key }; order.append(key)
                    while cache.count > SimilarityCandidates.limit || cachedBytes > Self.byteLimit {
                        cache.removeValue(forKey: order.removeFirst())
                    }
                }
                ready.append((asset, data))
            } catch SimilarityFailure.runtimeUnavailable { throw SimilarityFailure.runtimeUnavailable }
            catch is CancellationError { throw CancellationError() }
            catch { unavailable += 1 }
        }
        // Complete-link membership: every pair must pass, never a transitive similarity chain.
        var groups: [[Int]] = []
        for index in ready.indices {
            try Task.checkCancellation()
            var destination: Int?
            for groupIndex in groups.indices {
                var matches = true
                for other in groups[groupIndex] {
                    let a = ready[index].0; let b = ready[other].0
                    let aspectA = Double(a.width) / Double(max(a.height, 1)); let aspectB = Double(b.width) / Double(max(b.height, 1))
                    guard abs(aspectA - aspectB) <= 0.05,
                          abs((a.creationDate ?? .distantPast).timeIntervalSince(b.creationDate ?? .distantFuture)) <= 120 else { matches = false; break }
                    let distance = try await printer.distance(ready[index].1, ready[other].1)
                    if distance > Self.threshold { matches = false; break }
                }
                if matches { destination = groupIndex; break }
            }
            if let destination { groups[destination].append(index) } else { groups.append([index]) }
        }
        try Task.checkCancellation()
        return SimilarityReport(groups: groups.filter { $0.count > 1 }.map { SimilarityGroup(assetIDs: $0.map { ready[$0].0.id }) }, candidateCount: selected.assets.count, unavailableCount: unavailable, truncated: selected.truncated)
    }
}
