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
        return formatter.string(from: start)
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
        let ordered = assets.sorted {
            if $0.creationDate != $1.creationDate { return ($0.creationDate ?? .distantFuture) < ($1.creationDate ?? .distantFuture) }
            return $0.id < $1.id
        }
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
    func random<R: RandomNumberGenerator>(in assets: [PhotoAssetSnapshot], using generator: inout R) -> ReviewSegment? {
        segments(in: assets).randomElement(using: &generator)
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
