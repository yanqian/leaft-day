import Foundation

struct ReviewIntent: Equatable, Sendable {
    enum Kind: String, Sendable { case previous, next, favorite, pending }
    let assetID: String
    let kind: Kind
}

struct ReviewGestureRouter {
    enum Axis { case horizontal, vertical }
    private var target: String?
    private var axis: Axis?
    private var rejected = false
    mutating func update(x: Double, y: Double, assetID: String?, blocked: Bool) {
        if blocked { rejected = true; return }
        guard let assetID else { rejected = true; return }
        if target == nil { target = assetID }
        guard target == assetID else { rejected = true; return }
        guard axis == nil, max(abs(x), abs(y)) >= 18 else { return }
        if abs(x) >= abs(y) * 1.25 { axis = .horizontal }
        else if abs(y) >= abs(x) * 1.25 { axis = .vertical }
    }
    mutating func end(x: Double, y: Double, currentID: String?, blocked: Bool) -> ReviewIntent? {
        defer { reset() }
        guard !blocked, !rejected, let target, target == currentID, let axis else { return nil }
        switch axis {
        case .horizontal where abs(x) >= 65: return ReviewIntent(assetID: target, kind: x < 0 ? .next : .previous)
        case .vertical where abs(y) >= 85: return ReviewIntent(assetID: target, kind: y < 0 ? .pending : .favorite)
        default: return nil
        }
    }
    mutating func reset() { target = nil; axis = nil; rejected = false }
    mutating func cancel() { if target != nil { rejected = true } else { reset() } }
}
