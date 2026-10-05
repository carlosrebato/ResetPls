import Foundation
import Testing
@testable import AIUsageCore

struct DualQuotaPaceTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func snapshot(
        session: Double? = 10, weekly: Double = 10,
        sessionElapsedMinutes: Double = 90, weeklyElapsedDays: Double = 2,
        provider: UsageProviderID = .claude, source: UsageSource = .live,
        weeklyDuration: Double? = 7 * 86_400
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            id: provider,
            session: UsageWindow(usedPercent: session,
                resetsAt: session == nil ? nil : now.addingTimeInterval(18_000 - sessionElapsedMinutes * 60),
                durationSeconds: session == nil ? nil : 18_000),
            weekly: UsageWindow(usedPercent: weekly,
                resetsAt: now.addingTimeInterval((7 - weeklyElapsedDays) * 86_400),
                durationSeconds: weeklyDuration),
            observedAt: now, source: source, message: nil
        )
    }

    @Test func healthySessionAndWeekDoNotDuplicatePositiveCopy() {
        let reading = snapshot()
        #expect(reading.sessionPaceStatus(at: now) == .onTrack)
        #expect(reading.weeklyRisk(at: now)?.state == .roomToSpare)
        #expect(reading.weeklyPaceNotice(at: now) == nil)
        #expect(reading.preferredPaceNotice(at: now) == .session(.onTrack))
        #expect(reading.signal(at: now) == .normal)
    }

    @Test func tightSecondaryWeekAddsContextWithoutTurningTheDotAmber() throws {
        let reading = snapshot(weekly: 25)
        let week = try #require(reading.weeklyPaceNotice(at: now))
        #expect(week.state == .onTrack)
        #expect(reading.sessionPaceStatus(at: now) == .onTrack)
        #expect(reading.preferredPaceNotice(at: now) == .weekly(week))
        #expect(reading.signal(at: now) == .normal)
        #expect(AppLanguage.spanish.paceNoticeText(.weekly(week)) ==
            "A este ritmo, podrías acercarte al límite semanal")
        #expect(AppLanguage.english.paceNoticeText(.weekly(week)) ==
            "At this pace, you could come close to your weekly limit")
    }

    @Test func safeSessionCanHaveAnAmberOrRedWeeklyAlert() throws {
        for (used, state, signal) in [
            (32.0, WeeklyRiskState.atRisk, ProviderSignal.warning),
            (40.0, .highRisk, .critical)
        ] {
            let reading = snapshot(weekly: used)
            let week = try #require(reading.weeklyPaceNotice(at: now))
            #expect(reading.sessionPaceStatus(at: now) == .onTrack)
            #expect(week.state == state)
            #expect(reading.signal(at: now) == signal)
            #expect(reading.primaryQuotaID == .session)
            #expect(reading.displaysWeeklyReset == false)
            // The primary estimate still describes the session, while the
            // compact notice and global signal can warn about the week.
            #expect(reading.paceEstimate(at: now) == .onTrackToReset)
            #expect(reading.preferredPaceNotice(at: now) == .weekly(week))
        }
    }

    @Test func neitherQuotaCanDowngradeAMoreUrgentAlert() throws {
        let sessionRisk = snapshot(session: 60, weekly: 10, sessionElapsedMinutes: 60)
        guard case .session(.limitIn)? = sessionRisk.preferredPaceNotice(at: now) else {
            Issue.record("A healthy secondary week must not hide a session warning")
            return
        }
        #expect(sessionRisk.weeklyPaceNotice(at: now) == nil)
        #expect(sessionRisk.signal(at: now) == .warning)
        let both = snapshot(session: 60, weekly: 32, sessionElapsedMinutes: 60)
        #expect(both.weeklyPaceNotice(at: now)?.state == .atRisk)
        guard case .session(.limitIn)? = both.preferredPaceNotice(at: now) else {
            Issue.record("When both warn, the compact notice should retain the session ETA")
            return
        }
        let highWeek = snapshot(session: 60, weekly: 40, sessionElapsedMinutes: 60)
        let week = try #require(highWeek.weeklyPaceNotice(at: now))
        #expect(highWeek.preferredPaceNotice(at: now) == .weekly(week))
        #expect(highWeek.signal(at: now) == .critical)
        let criticalSession = snapshot(session: 87, weekly: 32, sessionElapsedMinutes: 64)
        #expect(criticalSession.weeklyPaceNotice(at: now)?.state == .atRisk)
        #expect(criticalSession.signal(at: now) == .critical)
    }

    @Test func weeklyOnlyProviderRetainsItsExistingNotice() throws {
        let reading = snapshot(session: nil, weekly: 10, provider: .codex)
        let week = try #require(reading.weeklyPaceNotice(at: now))
        #expect(week.state == .roomToSpare)
        #expect(reading.sessionPaceStatus(at: now) == nil)
        #expect(reading.preferredPaceNotice(at: now) == .weekly(week))
        #expect(AppLanguage.english.paceNoticeText(.weekly(week)) ==
            "At this pace, you should stay comfortably within your weekly limit")
    }

    @Test func smallEarlyWeeklyUsageDoesNotInventAnAlertOrSecondLine() {
        let reading = snapshot(weekly: 3, weeklyElapsedDays: 0.01)
        #expect(reading.weeklyRisk(at: now)?.projectedPercent == 21)
        #expect(reading.weeklyPaceNotice(at: now) == nil)
        #expect(reading.signal(at: now) == .normal)
    }

    @Test func savedUnverifiedAndBlockedQuotasDoNotClaimLiveSecondaryPace() {
        let cached = snapshot(weekly: 40, source: .cached)
        #expect(cached.weeklyPaceNotice(at: now) == nil)
        #expect(cached.signal(at: now) == .cached)
        let live = snapshot(weekly: 40)
        #expect(live.weeklyPaceNotice(at: now.addingTimeInterval(601)) == nil)
        #expect(live.signal(at: now.addingTimeInterval(601)) == .cached)
        let unverified = snapshot(weekly: 40, weeklyDuration: nil)
        #expect(unverified.weeklyPaceNotice(at: now) == nil)
        let blocked = snapshot(weekly: 100)
        #expect(blocked.weeklyPaceNotice(at: now) == nil)
        #expect(blocked.sessionPaceStatus(at: now) == nil)
        #expect(blocked.signal(at: now) == .critical)
    }

    @Test func identicalQuotaEvidenceUsesTheSamePolicyForBothProvidersAndAfterRestart() throws {
        let claude = snapshot(weekly: 32)
        let codex = snapshot(weekly: 32, provider: .codex)
        #expect(claude.weeklyPaceNotice(at: now) == codex.weeklyPaceNotice(at: now))
        #expect(claude.signal(at: now) == codex.signal(at: now))
        let restored = try JSONDecoder().decode(ProviderUsageSnapshot.self,
            from: JSONEncoder().encode(claude))
        #expect(restored.weeklyPaceNotice(at: now) == claude.weeklyPaceNotice(at: now))
        #expect(restored.preferredPaceNotice(at: now) == claude.preferredPaceNotice(at: now))
    }
}
