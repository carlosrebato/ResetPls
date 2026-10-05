import Foundation
import Testing
@testable import AIUsageCore

struct SessionPaceRobustnessTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func session(
        _ percent: Double, minute: Double, previous: ProviderUsageSnapshot? = nil,
        resetDrift: Double = 0, source: UsageSource = .live,
        duration: Double? = 18_000, hasReset: Bool = true
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            id: .claude,
            session: UsageWindow(usedPercent: percent,
                resetsAt: hasReset ? start.addingTimeInterval(18_000 + resetDrift) : nil,
                durationSeconds: duration),
            weekly: UsageWindow(usedPercent: nil, resetsAt: nil),
            observedAt: start.addingTimeInterval(minute * 60),
            source: source, message: nil
        ).recordingPace(previous: previous)
    }

    @Test func oneValidReadingAlwaysEstimatesWithoutInventingMoreEvidence() throws {
        for minute in [0.0, 0.1, 2, 15, 64, 240, 299] {
            for percent in [0.4, 2, 19.9, 20, 60, 69, 70, 87, 99.9] {
                let reading = session(percent, minute: minute)
                let assessment = try #require(reading.sessionPaceAssessment(at: reading.observedAt))
                #expect(assessment.reason == .estimated)
                #expect(assessment.status != .measuring && assessment.status != .newSession)
                #expect(assessment.projectedPercentAtReset?.isFinite == true)
                #expect(reading.paceEstimate(at: reading.observedAt) == reading.sessionPaceEstimate(at: reading.observedAt))
            }
        }
        let safe = session(60, minute: 240)
        #expect(safe.sessionPaceStatus(at: safe.observedAt) == .onTrack)
    }

    @Test func smallFirstReadingsStayNeutralFromTheResetInstant() {
        for minute in [0.0, 0.01, 1, 2, 5, 10, 15] {
            for percent in [0.0, 0.4, 1, 2, 4] {
                let reading = session(percent, minute: minute)
                #expect(reading.signal(at: reading.observedAt) == .normal)
            }
        }
        let fractional = session(0.4, minute: 10)
        #expect(fractional.sessionPaceStatus(at: fractional.observedAt) == .onTrack)
        let zero = session(0, minute: 10, hasReset: false)
        #expect(zero.sessionPaceStatus(at: zero.observedAt) == .noUsage)
    }

    @Test func oldTwentyAndSeventyPercentCutoffsAreContinuous() throws {
        for (minute, before, after) in [(15.0, 19.9, 20.0), (5.0, 69.0, 70.0)] {
            let first = session(before, minute: minute)
            let second = session(after, minute: minute)
            guard case .limitIn(let firstETA)? = first.sessionPaceStatus(at: first.observedAt),
                  case .limitIn(let secondETA)? = second.sessionPaceStatus(at: second.observedAt) else {
                Issue.record("Both sides of a former arbitrary cutoff must use the same estimate")
                continue
            }
            #expect(abs(firstETA - secondETA) < 30)
        }
    }

    @Test func briefPauseDoesNotEraseEarlierConsumptionButSustainedPauseCanRecover() throws {
        var reading = session(87, minute: 64)
        for minute in [69.0, 74] { reading = session(87, minute: minute, previous: reading) }
        guard case .limitIn(let eta)? = reading.sessionPaceStatus(at: reading.observedAt) else {
            Issue.record("A ten-minute pause must not instantly claim the session is safe")
            return
        }
        #expect(eta > 10 * 60 && eta < 12 * 60)
        for minute in stride(from: 79.0, through: 124.0, by: 5) {
            reading = session(87, minute: minute, previous: reading)
        }
        #expect(reading.sessionPaceStatus(at: reading.observedAt) == .onTrack)
        #expect(reading.sessionPaceAssessment(at: reading.observedAt)?.basis == .blendedRecentTrend)
        // Resuming use must produce a finite estimate, not stick in the idle state.
        for (minute, percent) in [(129.0, 89.0), (134.0, 93.0)] {
            reading = session(percent, minute: minute, previous: reading)
        }
        guard case .limitIn(let resumedETA)? = reading.sessionPaceStatus(at: reading.observedAt) else {
            Issue.record("Resumed consumption must be reflected")
            return
        }
        #expect(resumedETA.isFinite && resumedETA > 0)
    }

    @Test func uiClockOnlyCountsDownTheExistingEstimateAndNeverInventsAPause() throws {
        let reading = session(50, minute: 30)
        let first = try #require(reading.sessionPaceAssessment(at: reading.observedAt))
        let later = try #require(reading.sessionPaceAssessment(at: reading.observedAt.addingTimeInterval(540)))
        #expect(first.estimatedLimitAt == later.estimatedLimitAt)
        #expect(first.projectedPercentAtReset == later.projectedPercentAtReset)
        #expect(first.ratePercentPerSecond == later.ratePercentPerSecond)
        #expect(later.status == .limitIn(1_260))
        #expect(reading.sessionPaceAssessment(at: reading.observedAt.addingTimeInterval(601))?.reason == .stale)
    }

    @Test func resetDriftRetainsEvidenceButRolloverAndCorrectionDiscardIt() {
        var reading = session(10, minute: 30)
        reading = session(11, minute: 35, previous: reading, resetDrift: 1)
        reading = session(12, minute: 40, previous: reading, resetDrift: 2)
        #expect(reading.paceHistory?.session.count == 3)
        #expect(reading.sessionPaceAssessment(at: reading.observedAt)?.reason == .estimated)
        let corrected = session(5, minute: 45, previous: reading, resetDrift: 2)
        #expect(corrected.paceHistory?.session.count == 1)
        let rollover = session(1, minute: 301, previous: reading, resetDrift: 18_000)
        #expect(rollover.paceHistory?.session.count == 1)
        #expect(rollover.sessionPaceAssessment(at: rollover.observedAt)?.basis == .initialWindowAverage)
    }

    @Test func cachedAndInvalidEvidenceExplainWhyTheEstimateIsUnavailable() {
        for (reading, reason) in [
            (session(87, minute: 64, source: .cached), SessionPaceReason.cached),
            (session(87, minute: 64, hasReset: false), .missingReset),
            (session(87, minute: 301), .invalidReset),
            (session(87, minute: 64, duration: .nan), .invalidDuration),
            (session(87, minute: 64, duration: 10 * 86_400), .invalidDuration),
            (session(.nan, minute: 64), .invalidReading),
            (session(87, minute: 64, duration: nil), .insufficientHistory)
        ] {
            let assessment = reading.sessionPaceAssessment(at: reading.observedAt)
            #expect(assessment?.reason == reason)
            #expect(assessment?.status == .unavailable)
        }
        let exhausted = session(100, minute: 64)
        #expect(exhausted.sessionPaceAssessment(at: exhausted.observedAt)?.reason == .exhausted)
        #expect(exhausted.sessionPaceStatus(at: exhausted.observedAt) == nil)
    }

    @Test func singleJumpDoesNotPreventTheWindowAverageAndSurvivesCacheRoundTrip() throws {
        var reading = session(30, minute: 30)
        reading = session(30, minute: 35, previous: reading)
        reading = session(60, minute: 40, previous: reading)
        #expect(reading.sessionPaceAssessment(at: reading.observedAt)?.basis == .windowAverage)
        let restored = try JSONDecoder().decode(ProviderUsageSnapshot.self, from: JSONEncoder().encode(reading))
        #expect(restored.sessionPaceAssessment(at: restored.observedAt) == reading.sessionPaceAssessment(at: reading.observedAt))
        let reopened = session(60, minute: 40)
        #expect(reopened.sessionPaceStatus(at: reopened.observedAt) == reading.sessionPaceStatus(at: reading.observedAt))
    }

    @Test func weeklyRiskDoesNotDependOnDeviceHistoryOrUIClock() {
        func weekly(_ minute: Double, percent: Double, previous: ProviderUsageSnapshot? = nil) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(id: .codex,
                session: UsageWindow(usedPercent: nil, resetsAt: nil),
                weekly: UsageWindow(usedPercent: percent, resetsAt: start.addingTimeInterval(7 * 86_400), durationSeconds: 7 * 86_400),
                observedAt: start.addingTimeInterval(minute * 60), source: .live, message: nil
            ).recordingPace(previous: previous)
        }
        let first = weekly(2 * 1_440, percent: 39)
        let rich = weekly(2 * 1_440 + 30, percent: 40, previous: first)
        let sparse = weekly(2 * 1_440 + 30, percent: 40)
        #expect(rich.weeklyRisk(at: rich.observedAt) == sparse.weeklyRisk(at: sparse.observedAt))
        #expect(rich.weeklyRisk(at: rich.observedAt)?.state == .highRisk)
        #expect(rich.weeklyRisk(at: rich.observedAt) == rich.weeklyRisk(at: rich.observedAt.addingTimeInterval(540)))
        #expect(rich.signal(at: rich.observedAt) == sparse.signal(at: sparse.observedAt))
    }
}
