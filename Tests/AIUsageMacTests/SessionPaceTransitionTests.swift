import Foundation
import Testing
@testable import AIUsageCore

struct SessionPaceTransitionTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func reading(_ percent: Double, minute: Double,
                         previous: ProviderUsageSnapshot? = nil,
                         resetMinute: Double = 300, source: UsageSource = .live,
                         provider: UsageProviderID = .claude) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(id: provider,
            session: UsageWindow(usedPercent: percent,
                resetsAt: start.addingTimeInterval(resetMinute * 60), durationSeconds: 18_000),
            weekly: UsageWindow(usedPercent: nil, resetsAt: nil),
            observedAt: start.addingTimeInterval(minute * 60), source: source, message: nil
        ).recordingPace(previous: previous)
    }

    @Test func approvedScenarioTableAndExactBilingualCopies() {
        let scenarios: [(Double, Double, SessionPaceStatus, String, String)] = [
            (0, 2, .noUsage, "Aún no hay uso registrado en esta sesión", "No session usage reported yet"),
            (1, 3, .newSession, "Sesión nueva · calculando ritmo", "New session · measuring pace"),
            (2, 20, .onTrack, "A este ritmo, llegarías al reinicio de sesión", "At this pace, you should make it to the session reset"),
            (10, 30, .measuring, "Calculando el ritmo de esta sesión", "Measuring this session's pace"),
            (40, 120, .measuring, "Calculando el ritmo de esta sesión", "Measuring this session's pace"),
            (25, 5, .limitIn(900), "A este ritmo, podrías agotar la sesión en ~15m", "At this pace, you could hit the session limit in ~15m"),
            (80, 290, .onTrack, "A este ritmo, llegarías al reinicio de sesión", "At this pace, you should make it to the session reset")
        ]
        for (percent, minute, expected, spanish, english) in scenarios {
            let snapshot = reading(percent, minute: minute)
            #expect(snapshot.sessionPaceStatus(at: snapshot.observedAt) == expected)
            #expect(AppLanguage.spanish.sessionPaceText(expected) == spanish)
            #expect(AppLanguage.english.sessionPaceText(expected) == english)
        }
        for (percent, minute, spanish, english) in [
            (87.0, 64.0, "A este ritmo, podrías agotar la sesión en ~10m", "At this pace, you could hit the session limit in ~10m"),
            (99.0, 295.0, "A este ritmo, podrías agotar la sesión en ~3m", "At this pace, you could hit the session limit in ~3m")
        ] {
            let snapshot = reading(percent, minute: minute)
            let status = snapshot.sessionPaceStatus(at: snapshot.observedAt)
            #expect(status.map(AppLanguage.spanish.sessionPaceText) == spanish)
            #expect(status.map(AppLanguage.english.sessionPaceText) == english)
        }
        let exhausted = reading(100, minute: 273)
        #expect(exhausted.sessionPaceStatus(at: exhausted.observedAt) == nil)
        #expect(AppLanguage.english.resetText(for: exhausted, now: exhausted.observedAt) == "Back in 27m")
    }

    @Test func startupCannotPromiseSafetyButSubstantialUseCanWarnImmediately() {
        for minute in [0.0, 1, 3, 10, 14] {
            let snapshot = reading(1, minute: minute)
            #expect(snapshot.sessionPaceStatus(at: snapshot.observedAt) == .newSession)
            #expect(snapshot.signal(at: snapshot.observedAt) == .normal)
        }
        let high = reading(25, minute: 5)
        #expect(high.sessionPaceStatus(at: high.observedAt) == .limitIn(900))
        #expect(high.signal(at: high.observedAt) == .warning)
        let sufficient = reading(2, minute: 20)
        #expect(sufficient.sessionPaceStatus(at: sufficient.observedAt) == .onTrack)
    }

    @Test func ambiguousFirstReadingCanProgressWithoutRestartingTheSession() {
        let first = reading(1, minute: 3)
        let uncertain = reading(5, minute: 15, previous: first)
        #expect(uncertain.sessionPaceStatus(at: uncertain.observedAt) == .measuring)
        let safe = reading(5, minute: 25, previous: uncertain)
        #expect(safe.sessionPaceStatus(at: safe.observedAt) == .onTrack)
    }

    @Test func boundaryKeepsEitherPriorConclusionAndRefreshesRiskETA() throws {
        let safe = reading(2, minute: 20)
        let safeBoundary = reading(10, minute: 30, previous: safe)
        #expect(safeBoundary.sessionPaceStatus(at: safeBoundary.observedAt) == .onTrack)
        #expect(safeBoundary.sessionPaceAssessment(at: safeBoundary.observedAt)?.reason == .stabilized)
        let risky = reading(8, minute: 20)
        let riskBoundary = reading(10, minute: 30, previous: risky)
        #expect(riskBoundary.sessionPaceStatus(at: riskBoundary.observedAt) == .limitIn(270 * 60))
        #expect(riskBoundary.sessionPaceAssessment(at: riskBoundary.observedAt)?.reason == .stabilized)
        #expect(risky.sessionPaceAssessment(at: risky.observedAt)?.estimatedLimitAt !=
                riskBoundary.sessionPaceAssessment(at: riskBoundary.observedAt)?.estimatedLimitAt)
        // Conclusion survives the one-hour rolling sample retention.
        let lateBoundary = reading(40, minute: 120, previous: riskBoundary)
        #expect(lateBoundary.sessionPaceStatus(at: lateBoundary.observedAt) == .limitIn(180 * 60))
    }

    @Test func clearWorseningAndRecoveryChangeTheConclusion() {
        let safe = reading(2, minute: 20)
        let risky = reading(20, minute: 30, previous: safe)
        #expect(risky.sessionPaceStatus(at: risky.observedAt) == .limitIn(120 * 60))
        let recovered = reading(20, minute: 180, previous: risky)
        #expect(recovered.sessionPaceStatus(at: recovered.observedAt) == .onTrack)
    }

    @Test func restartAndCacheRoundTripKeepConclusionButCachedDataCannotClaimLivePace() throws {
        let safe = reading(2, minute: 20)
        let boundary = reading(10, minute: 30, previous: safe)
        let restored = try JSONDecoder().decode(ProviderUsageSnapshot.self,
            from: JSONEncoder().encode(boundary))
        let cached = reading(10, minute: 30, previous: restored, source: .cached)
        #expect(cached.sessionPaceStatus(at: cached.observedAt) == .unavailable)
        let live = reading(10, minute: 31, previous: cached)
        #expect(live.sessionPaceStatus(at: live.observedAt) == .onTrack)
        #expect(live.sessionPaceAssessment(at: live.observedAt)?.reason == .stabilized)
    }

    @Test func rolloverCorrectionAndDifferentProviderDoNotInheritConclusion() {
        let risky = reading(8, minute: 20)
        let rollover = reading(1, minute: 303, previous: risky, resetMinute: 600)
        #expect(rollover.sessionPaceStatus(at: rollover.observedAt) == .newSession)
        #expect(rollover.paceHistory?.sessionConclusion == nil)
        let correction = reading(7, minute: 21, previous: risky)
        #expect(correction.sessionPaceStatus(at: correction.observedAt) == .measuring)
        #expect(correction.paceHistory?.sessionConclusion == nil)
        let other = reading(10, minute: 30, previous: risky, provider: .codex)
        #expect(other.sessionPaceStatus(at: other.observedAt) == .measuring)
    }

    @Test func clockAloneDoesNotFinishStartupOrChangeTheConclusion() {
        let first = reading(1, minute: 14)
        #expect(first.sessionPaceStatus(at: first.observedAt.addingTimeInterval(120)) == .newSession)
        let boundary = reading(10, minute: 30, previous: reading(2, minute: 20))
        #expect(boundary.sessionPaceStatus(at: boundary.observedAt.addingTimeInterval(120)) == .onTrack)
        #expect(boundary.sessionPaceStatus(at: boundary.observedAt.addingTimeInterval(601)) == .unavailable)
    }

    @Test func legacyHistoryWithoutConclusionStillDecodes() throws {
        let history = try JSONDecoder().decode(UsagePaceHistory.self,
            from: Data(#"{"session":[],"weekly":[]}"#.utf8))
        #expect(history.sessionConclusion == nil)
    }
}
