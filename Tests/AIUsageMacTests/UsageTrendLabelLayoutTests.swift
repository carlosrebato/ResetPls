import Foundation
import Testing
@testable import AIUsageDesignSystem

struct UsageTrendLabelLayoutTests {
    @Test func labelsStayInsideAndSeparateAtBothEdgesAndCoincidentPoints() throws {
        let bounds = CGRect(x: 280, y: 4, width: 72, height: 78)
        for firstY in [-20.0, 4, 16, 45, 78, 100] {
            for secondY in [-20.0, 4, 16, 45, 78, 100] {
                for width in [28.0, 42, 64] {
                    let targets = [
                        CGRect(x: 275, y: firstY, width: width, height: 12),
                        CGRect(x: 350, y: secondY, width: 48, height: 14)
                    ]
                    let frames = UsageTrendLabelLayout.frames(for: targets, in: bounds)
                    try #require(frames.count == 2)
                    #expect(frames.allSatisfy(bounds.contains))
                    #expect(frames[0].maxY + 4 <= frames[1].minY
                            || frames[1].maxY + 4 <= frames[0].minY)
                    #expect(frames[0].size == targets[0].size)
                    #expect(frames[1].size == targets[1].size)
                }
            }
        }
    }

    @Test func separatedLabelsKeepTheirOriginalVerticalPosition() {
        let bounds = CGRect(x: 280, y: 4, width: 72, height: 78)
        let targets = [
            CGRect(x: 280, y: 16, width: 40, height: 12),
            CGRect(x: 280, y: 60, width: 48, height: 12)
        ]
        #expect(UsageTrendLabelLayout.frames(for: targets, in: bounds) == targets)
    }

    @Test func aSingleLabelIsClampedWithoutResizingTheText() {
        let bounds = CGRect(x: 280, y: 4, width: 72, height: 78)
        let targets = [CGRect(x: 400, y: 100, width: 64, height: 12)]
        let frames = UsageTrendLabelLayout.frames(for: targets, in: bounds)
        #expect(frames == [CGRect(x: 288, y: 70, width: 64, height: 12)])
    }

    @Test func anImpossibleAreaOmitsLabelsRatherThanClippingThem() {
        let targets = [CGRect(x: 0, y: 0, width: 48, height: 12)]
        #expect(UsageTrendLabelLayout.frames(for: targets, in: .zero).isEmpty)
        #expect(UsageTrendLabelLayout.frames(
            for: targets, in: CGRect(x: 0, y: 0, width: 30, height: 78)
        ).isEmpty)
    }
}
