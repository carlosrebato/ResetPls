import Foundation

enum UsageTrendInspection {
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
