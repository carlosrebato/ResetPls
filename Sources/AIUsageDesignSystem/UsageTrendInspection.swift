import Foundation

enum UsageTrendInspection {
    /// Keep inspection values away from nearby series without reserving a
    /// permanent empty lane above the percentage plot.
    static func labelY(height: CGFloat, top: CGFloat, bottom: CGFloat,
                       occupied: [ClosedRange<CGFloat>]) -> CGFloat {
        let last = max(top, bottom - height)
        var best = top
        var bestOverlap = CGFloat.infinity
        var candidate = top
        while candidate <= last {
            let overlap = occupied.reduce(CGFloat.zero) { total, range in
                total + max(0, min(candidate + height, range.upperBound)
                    - max(candidate, range.lowerBound))
            }
            if overlap < bestOverlap {
                best = candidate
                bestOverlap = overlap
            }
            if overlap == 0 { break }
            candidate += 1
        }
        return best
    }

    static func index(at location: CGPoint, size: CGSize, plotLeft: CGFloat,
                      plotRight: CGFloat, dayCount: Int) -> Int? {
        guard dayCount > 0, size.width > 0, size.height > 0,
              location.x.isFinite, location.y.isFinite,
              plotLeft.isFinite, plotRight.isFinite,
              location.x >= 0, location.x <= size.width,
              location.y >= 0, location.y <= size.height else { return nil }
        let step = max((plotRight - plotLeft) / CGFloat(max(dayCount - 1, 1)), 1)
        return min(max(Int(((location.x - plotLeft) / step).rounded()), 0), dayCount - 1)
    }
}
