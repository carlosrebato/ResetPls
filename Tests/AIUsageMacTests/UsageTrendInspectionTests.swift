import Foundation
import Testing
@testable import AIUsageDesignSystem

struct UsageTrendInspectionTests {
    @Test func labelMovesBelowHighPointsWithoutReservingAHeaderLane() {
        let y = UsageTrendInspection.labelY(height: 20, top: 0, bottom: 78, occupied: [0...16])
        #expect(y >= 16)
        #expect(y + 20 <= 78)
    }

    @Test func labelUsesUpperSpaceForLowValuesAndFitsBetweenSeries() {
        #expect(UsageTrendInspection.labelY(height: 20, top: 0, bottom: 78, occupied: [60...86]) == 0)
        let y = UsageTrendInspection.labelY(height: 20, top: 0, bottom: 78, occupied: [0...16, 60...86])
        #expect(y >= 16 && y + 20 <= 60)
    }

    @Test func crowdedAndEmptyPlotsKeepTheLabelInsideTheChart() {
        #expect(UsageTrendInspection.labelY(height: 20, top: 0, bottom: 78, occupied: []) == 0)
        let y = UsageTrendInspection.labelY(height: 20, top: 0, bottom: 78, occupied: [0...78])
        #expect(y >= 0 && y + 20 <= 78)
    }

    @Test func selectsNearestDayAndClampsEndpointGutter() {
        let size = CGSize(width: 340, height: 180)
        for index in 0..<7 {
            #expect(UsageTrendInspection.index(at: CGPoint(x: 3 + index * 45, y: 70),
                size: size, plotLeft: 3, plotRight: 273, dayCount: 7) == index)
        }
        #expect(UsageTrendInspection.index(at: CGPoint(x: 0, y: 70), size: size,
            plotLeft: 3, plotRight: 273, dayCount: 7) == 0)
        #expect(UsageTrendInspection.index(at: CGPoint(x: 339, y: 70), size: size,
            plotLeft: 3, plotRight: 273, dayCount: 7) == 6)
    }

    @Test func outsideEmptyAndInvalidCoordinatesHaveNoSelection() {
        for point in [CGPoint(x: -1, y: 30), CGPoint(x: 341, y: 30),
                      CGPoint(x: 50, y: -1), CGPoint(x: 50, y: 181),
                      CGPoint(x: CGFloat.nan, y: 30)] {
            #expect(UsageTrendInspection.index(at: point, size: CGSize(width: 340, height: 180),
                plotLeft: 3, plotRight: 273, dayCount: 7) == nil)
        }
        #expect(UsageTrendInspection.index(at: .zero, size: CGSize(width: 340, height: 180),
            plotLeft: 3, plotRight: 273, dayCount: 0) == nil)
    }
}
