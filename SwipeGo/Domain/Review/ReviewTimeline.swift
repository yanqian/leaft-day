import Foundation

struct ReviewSegment: Sendable, Equatable, Identifiable {
    var id: String { assetIDs.first ?? "empty" }
    let assetIDs: [String]
    let start: Date?
    let end: Date?
    func title(calendar: Calendar) -> String {
        guard let start else { return "日期未知" }
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_CN"); formatter.dateFormat = "yyyy年M月d日"
        let first = formatter.string(from: start)
        guard let end else { return "\(first)起 · 含日期未知项目" }
        guard !calendar.isDate(start, inSameDayAs: end) else { return first }
        if calendar.component(.year, from: start) == calendar.component(.year, from: end) { formatter.dateFormat = "M月d日" }
        return "\(first) – \(formatter.string(from: end))"
    }
}

struct ReviewTimeline: Sendable {
    let calendar: Calendar
    let gap: TimeInterval
    init(timeZone: TimeZone = .current, gap: TimeInterval = 2 * 60 * 60) {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        self.calendar = calendar; self.gap = max(1, gap)
    }
    func segments(in assets: [PhotoAssetSnapshot]) -> [ReviewSegment] {
        // Unknown dates are explicitly separate; they never acquire an invented date.
        let ordered = orderedAssets(assets)
        var groups: [[PhotoAssetSnapshot]] = []
        var seen = Set<String>()
        for asset in ordered where seen.insert(asset.id).inserted {
            if let previous = groups.last?.last {
                switch (previous.creationDate, asset.creationDate) {
                case let (before?, after?) where calendar.isDate(before, inSameDayAs: after) && after.timeIntervalSince(before) <= gap:
                    groups[groups.count - 1].append(asset)
                case (nil, nil): groups[groups.count - 1].append(asset)
                default: groups.append([asset])
                }
            } else { groups.append([asset]) }
        }
        return groups.map { ReviewSegment(assetIDs: $0.map(\.id), start: $0.first?.creationDate, end: $0.last?.creationDate) }
    }
    func random<R: RandomNumberGenerator>(in assets: [PhotoAssetSnapshot], using generator: inout R, avoiding previous: ReviewSegment? = nil) -> ReviewSegment? {
        let groups = segments(in: assets)
        let multiple = groups.filter { $0.assetIDs.count > 1 }
        let preferred = multiple.isEmpty ? groups : multiple
        guard let selected = preferred.randomElement(using: &generator) else { return nil }
        let ordered = orderedAssets(assets)
        func candidate(_ segment: ReviewSegment) -> ReviewSegment? {
            if segment.assetIDs.count > 1 {
                let ids = Set(segment.assetIDs.prefix(60))
                return batch(ordered.filter { ids.contains($0.id) })
            }
            return nearby(in: ordered, anchor: segment.id, excluding: [], limit: 12)
        }
        let first = candidate(selected)
        guard let previous, first?.assetIDs == previous.assetIDs else { return first }
        for group in preferred.shuffled(using: &generator) {
            if let alternative = candidate(group), alternative.assetIDs != previous.assetIDs { return alternative }
        }
        // Keep the existing multi-item preference, but allow sparse nearby
        // memories when they are the only alternative to the visited segment.
        if !multiple.isEmpty {
            for group in groups.filter({ $0.assetIDs.count == 1 }).shuffled(using: &generator) {
                if let alternative = candidate(group), alternative.assetIDs != previous.assetIDs { return alternative }
            }
        }
        return first
    }
    func orderedAssets(_ assets: [PhotoAssetSnapshot]) -> [PhotoAssetSnapshot] {
        var seen = Set<String>()
        return assets.sorted {
            if $0.creationDate != $1.creationDate { return ($0.creationDate ?? .distantFuture) < ($1.creationDate ?? .distantFuture) }
            return $0.id < $1.id
        }.filter { seen.insert($0.id).inserted }
    }
    func batch(_ ordered: [PhotoAssetSnapshot]) -> ReviewSegment? {
        guard !ordered.isEmpty else { return nil }
        return ReviewSegment(assetIDs: ordered.map(\.id), start: ordered.first?.creationDate, end: ordered.last?.creationDate)
    }
    func recent(in assets: [PhotoAssetSnapshot]) -> ReviewSegment? {
        let ordered = orderedAssets(assets)
        let dated = ordered.filter { $0.creationDate != nil }
        return batch(Array((dated.isEmpty ? ordered : dated).suffix(60)))
    }
    /// Input is already sorted and scoped. No media downloads are triggered here.
    func following(in ordered: [PhotoAssetSnapshot], anchor: String, excluding: Set<String>) -> [String] {
        guard let index = ordered.firstIndex(where: { $0.id == anchor }) else { return [] }
        return Array(ordered.dropFirst(index + 1).lazy.map(\.id).filter { !excluding.contains($0) }.prefix(60))
    }
    func nearby(in ordered: [PhotoAssetSnapshot], anchor: String, excluding: Set<String>, limit: Int = 12) -> ReviewSegment? {
        guard let center = ordered.firstIndex(where: { $0.id == anchor }) else { return nil }
        var selected: [Int] = []; var radius = 0
        while selected.count < min(12, max(1, limit)) && (center - radius >= 0 || center + radius < ordered.count) {
            let indices = radius == 0 ? [center] : [center - radius, center + radius]
            for index in indices where ordered.indices.contains(index) && !excluding.contains(ordered[index].id) {
                if selected.count < min(12, max(1, limit)) { selected.append(index) }
            }
            radius += 1
        }
        return batch(selected.sorted().map { ordered[$0] })
    }
    func lastYearDate(relativeTo today: Date) -> Date? {
        var wanted = calendar.dateComponents([.year, .month, .day], from: today)
        wanted.year = (wanted.year ?? 1) - 1
        // Calendar normalizes invalid 29 Feb; compare back so it remains an empty state.
        guard let date = calendar.date(from: wanted),
              calendar.dateComponents([.year, .month, .day], from: date) == wanted else { return nil }
        return date
    }
    func lastYearToday(in assets: [PhotoAssetSnapshot], today: Date = .now) -> ReviewSegment? {
        guard let date = lastYearDate(relativeTo: today) else { return nil }
        let groups = segments(in: assets.filter { $0.creationDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false })
        guard let first = groups.first, let last = groups.last else { return nil }
        // This entry deliberately revisits the whole matching calendar day in order.
        return ReviewSegment(assetIDs: groups.flatMap(\.assetIDs), start: first.start, end: last.end)
    }
}
