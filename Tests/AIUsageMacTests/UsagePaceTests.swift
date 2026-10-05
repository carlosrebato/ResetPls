import Foundation
import Testing
@testable import AIUsageCore

struct UsagePaceTests {
    private let start = Date(timeIntervalSince1970: 10_000)
    private let week: TimeInterval = 7 * 24 * 60 * 60

    private func fiveHourSession(used: Double, elapsedMinutes: Double) -> ProviderUsageSnapshot {
        let duration: TimeInterval = 5 * 3_600
        let observed = start.addingTimeInterval(elapsedMinutes * 60)
        return ProviderUsageSnapshot(
            id: .claude,
            session: UsageWindow(
                usedPercent: used,
                resetsAt: start.addingTimeInterval(duration),
                durationSeconds: duration
            ),
            weekly: UsageWindow(usedPercent: nil, resetsAt: nil),
            observedAt: observed,
            source: .live,
            message: nil
        ).recordingPace(previous: nil)
    }

    @Test func substantialSessionUsageGetsAPaceEvenWithSparseReadings() {
        let reading = fiveHourSession(used: 87, elapsedMinutes: 64)
        guard case .limitIn(let eta)? = reading.sessionPaceStatus(at: reading.observedAt) else {
            Issue.record("87% after an hour must not remain measuring")
            return
        }
        #expect(eta > 9 * 60 && eta < 11 * 60)
        #expect(reading.signal(at: reading.observedAt) == .critical)
        #expect(AppLanguage.english.sessionPaceText(.limitIn(eta)) ==
            "At this pace, you could hit the session limit in ~10m")
    }

    @Test func firstMinutesAndTinyReadingsDoNotProduceFalsePaceWarnings() {
        let tiny = fiveHourSession(used: 2, elapsedMinutes: 2)
        #expect(tiny.sessionPaceStatus(at: tiny.observedAt) == .newSession)
        #expect(tiny.signal(at: tiny.observedAt) == .normal)
        let early = fiveHourSession(used: 25, elapsedMinutes: 5)
        #expect(early.sessionPaceStatus(at: early.observedAt) == .limitIn(900))
        let zero = fiveHourSession(used: 0, elapsedMinutes: 1)
        #expect(zero.sessionPaceStatus(at: zero.observedAt) == .noUsage)
        let nearReset = fiveHourSession(used: 80, elapsedMinutes: 290)
        #expect(nearReset.sessionPaceStatus(at: nearReset.observedAt) == .onTrack)
    }

    @Test func approvedSessionAndWeeklyCopyIsBilingual() {
        #expect(AppLanguage.english.sessionPaceText(.noUsage) == "No session usage reported yet")
        #expect(AppLanguage.spanish.sessionPaceText(.noUsage) == "Aún no hay uso registrado en esta sesión")
        #expect(AppLanguage.english.sessionPaceText(.newSession) == "New session · measuring pace")
        #expect(AppLanguage.spanish.sessionPaceText(.newSession) == "Sesión nueva · calculando ritmo")
        #expect(AppLanguage.english.sessionPaceText(.measuring) == "Measuring this session's pace")
        #expect(AppLanguage.spanish.sessionPaceText(.measuring) == "Calculando el ritmo de esta sesión")
        #expect(AppLanguage.english.sessionPaceText(.unavailable) == "Session pace unavailable")
        #expect(AppLanguage.spanish.sessionPaceText(.unavailable) == "Ritmo de sesión no disponible")
        #expect(AppLanguage.english.sessionPaceText(.onTrack) == "At this pace, you should make it to the session reset")
        #expect(AppLanguage.spanish.sessionPaceText(.onTrack) == "A este ritmo, llegarías al reinicio de sesión")
        #expect(AppLanguage.spanish.sessionPaceText(.limitIn(600)) == "A este ritmo, podrías agotar la sesión en ~10m")
        for (state, english, spanish) in [
            (WeeklyRiskState.roomToSpare, "At this pace, you should stay comfortably within your weekly limit", "A este ritmo, llegarías al reinicio semanal con margen"),
            (.onTrack, "At this pace, you could come close to your weekly limit", "A este ritmo, podrías acercarte al límite semanal"),
            (.atRisk, "Risk of reaching the weekly limit", "Riesgo de alcanzar el límite semanal"),
            (.highRisk, "High risk of reaching the weekly limit", "Riesgo alto de alcanzar el límite semanal")
        ] {
            let assessment = WeeklyRiskAssessment(state: state, usedPercent: 25, elapsedPercent: 25, projectedPercent: 100)
            #expect(AppLanguage.english.weeklyRiskText(assessment) == english)
            #expect(AppLanguage.spanish.weeklyRiskText(assessment) == spanish)
        }
    }

    private func weeklyOnly(
        used: Double, elapsedDays: Double, source: UsageSource = .live,
        duration: TimeInterval? = 7 * 24 * 60 * 60
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            id: .codex,
            session: UsageWindow(usedPercent: nil, resetsAt: nil),
            weekly: UsageWindow(
                usedPercent: used,
                resetsAt: start.addingTimeInterval(week),
                durationSeconds: duration
            ),
            observedAt: start.addingTimeInterval(elapsedDays * 86_400),
            source: source,
            message: nil
        )
    }

    @Test func weeklyRiskAndResetCopyAreRestoredForVerifiedWeeklyOnlyQuota() throws {
        let reading = weeklyOnly(used: 25, elapsedDays: 2)
        let assessment = try #require(reading.weeklyRisk(at: reading.observedAt))
        #expect(assessment.state == .onTrack)
        #expect(abs(assessment.projectedPercent - 87.5) < 0.001)
        #expect(AppLanguage.spanish.weeklyRiskText(assessment) == "A este ritmo, podrías acercarte al límite semanal")
        #expect(AppLanguage.spanish.resetLabel(for: reading) == "RESETEO SEM.")
        #expect(reading.signal(at: reading.observedAt) == .normal)
    }

    @Test func weeklyRiskNeedsVerifiedFreshEvidenceAndConfirmedHighRisk() {
        let early = weeklyOnly(used: 20, elapsedDays: 0.5)
        #expect(early.weeklyRisk(at: early.observedAt)?.state == .atRisk)
        #expect(early.signal(at: early.observedAt) == .warning)
        let unverified = weeklyOnly(used: 40, elapsedDays: 2, duration: nil)
        #expect(unverified.weeklyRisk(at: unverified.observedAt) == nil)
        let cached = weeklyOnly(used: 40, elapsedDays: 2, source: .cached)
        #expect(cached.weeklyRisk(at: cached.observedAt) == nil)
        #expect(cached.signal(at: cached.observedAt) == .cached)
        var confirmed: ProviderUsageSnapshot?
        for (minutes, used) in [(0.0, 39.0), (15.0, 39.5), (30.0, 40.0)] {
            confirmed = weeklyOnly(used: used, elapsedDays: 2 + minutes / 1_440)
                .recordingPace(previous: confirmed)
        }
        #expect(confirmed?.weeklyRisk(at: confirmed!.observedAt)?.state == .highRisk)
        #expect(confirmed?.signal(at: confirmed!.observedAt) == .critical)
    }

    @Test func smallReadingAtWeeklyRolloverDoesNotTriggerTheSemaphore() throws {
        let fiveMinutes = 5.0 / 1_440
        let tiny = weeklyOnly(used: 1.4, elapsedDays: fiveMinutes)
        let assessment = try #require(tiny.weeklyRisk(at: tiny.observedAt))
        #expect(assessment.state == .roomToSpare)
        #expect(abs(assessment.projectedPercent - 9.8) < 0.001)
        #expect(tiny.signal(at: tiny.observedAt) == .normal)
        #expect(AppLanguage.english.weeklyRiskHelp(assessment) ==
            "You've used 1% of your weekly limit. This early estimate may change as you use the service.")
        #expect(AppLanguage.spanish.weeklyRiskHelp(assessment) ==
            "Has usado el 1 % de tu límite semanal. Esta estimación inicial puede cambiar según tu uso.")

        let meaningful = weeklyOnly(used: 18, elapsedDays: fiveMinutes)
        #expect(meaningful.weeklyRisk(at: meaningful.observedAt)?.state == .atRisk)
        #expect(meaningful.signal(at: meaningful.observedAt) == .warning)
    }

    @Test func firstDayProjectionMatchesWeeklyScenariosAndJoinsActualTimeContinuously() throws {
        let scenarios: [(hours: Double, used: Double, projected: Double, state: WeeklyRiskState)] = [
            (0, 0, 0, .roomToSpare),
            (3 + 20.0 / 60, 3, 21, .roomToSpare),
            (6, 10, 70, .roomToSpare),
            (6, 15, 105, .onTrack),
            (6, 18, 126, .atRisk),
            (12, 20, 140, .atRisk),
            (24, 15, 105, .onTrack),
            (48, 30, 105, .onTrack),
            (48, 40, 140, .highRisk)
        ]
        for scenario in scenarios {
            let reading = weeklyOnly(used: scenario.used, elapsedDays: scenario.hours / 24)
            let assessment = try #require(reading.weeklyRisk(at: reading.observedAt))
            #expect(abs(assessment.projectedPercent - scenario.projected) < 0.001)
            #expect(assessment.state == scenario.state)
            #expect(reading.signal(at: reading.observedAt) == (
                scenario.state == .highRisk ? .critical : scenario.state == .atRisk ? .warning : .normal
            ))
        }
    }

    @Test func weeklyOnlySemaphoreIgnoresShortBurstsWhileUsingTheFirstDayEstimate() throws {

        var previous: ProviderUsageSnapshot?
        for (minute, percent) in [(0.0, 0.2), (10.0, 0.8), (20.0, 1.4)] {
            previous = weeklyOnly(used: percent, elapsedDays: minute / 1_440)
                .recordingPace(previous: previous)
        }
        let burst = try #require(previous)
        #expect(burst.paceEstimate(at: burst.observedAt) == .onTrackToReset)
        #expect(burst.signal(at: burst.observedAt) == .normal)
    }

    @Test func providerSignalUsesBothQuotasAndDoesNotMistakeMissingDataForAWarning() {
        let lowSessionHighWeek = snapshot(session: 9, weekly: 98)
        #expect(lowSessionHighWeek.signal(at: lowSessionHighWeek.observedAt) == .critical)
        let middleWeek = snapshot(session: 9, weekly: 72)
        #expect(middleWeek.signal(at: middleWeek.observedAt) == .warning)
        let noData = snapshot(session: nil, weekly: nil)
        #expect(noData.signal(at: noData.observedAt) == .unavailable)
    }

    private func snapshot(
        session: Double?, weekly: Double? = nil, seconds: Double = 0,
        sessionReset: Double? = 7_200, weeklyReset: Double? = 86_400,
        provider: UsageProviderID = .claude, source: UsageSource = .live
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            id: provider,
            session: UsageWindow(usedPercent: session, resetsAt: sessionReset.map { start.addingTimeInterval($0) }),
            weekly: UsageWindow(usedPercent: weekly, resetsAt: weeklyReset.map { start.addingTimeInterval($0) }),
            observedAt: start.addingTimeInterval(seconds), source: source, message: nil
        )
    }

    private func series(
        session: [Double], weekly: [Double]? = nil,
        sessionReset: Double = 7_200, weeklyReset: Double = 86_400
    ) -> ProviderUsageSnapshot {
        var previous: ProviderUsageSnapshot?
        for index in session.indices {
            previous = snapshot(
                session: session[index], weekly: weekly?[index], seconds: Double(index) * 300,
                sessionReset: sessionReset, weeklyReset: weeklyReset
            ).recordingPace(previous: previous)
        }
        return previous!
    }

    @Test func steadyConsumptionGivesAnETABeforeReset() {
        let reading = series(session: [60, 65, 70])
        #expect(reading.paceEstimate(at: reading.observedAt) == .limitIn(1_800, quota: .session))
    }

    @Test func flatIntervalsContributeToTheRegression() {
        let reading = series(session: [30, 35, 35, 40])
        #expect(reading.paceEstimate(at: reading.observedAt) == .insufficientData)
        #expect(reading.sessionPaceAssessment(at: reading.observedAt)?.projectedPercentAtReset == 103)
    }

    @Test func providerHistoriesAreKeptSeparate() {
        let claude = series(session: [60, 65, 70])
        let codex = snapshot(session: 75, seconds: 900, provider: .codex)
            .recordingPace(previous: claude)
        #expect(codex.paceHistory?.session.count == 1)
    }

    @Test func exactBoundaryWithoutAPriorConclusionRemainsUncertain() {
        for reset in [2_400.0, 2_399] {
            let reading = series(session: [60, 65, 70], sessionReset: reset)
            #expect(reading.paceEstimate(at: reading.observedAt) == .insufficientData)
        }
    }

    @Test func idleAndRecentlyIdleHaveNoInfiniteETA() {
        let idle = series(session: [30, 30, 30])
        #expect(idle.paceEstimate(at: idle.observedAt) == .onTrackToReset)
        var active = series(session: [30, 35, 40])
        // Once the active hour leaves the rolling window, flat samples describe current pace.
        for minute in stride(from: 65, through: 80, by: 5) {
            active = snapshot(session: 40, seconds: Double(minute) * 60)
                .recordingPace(previous: active)
        }
        #expect(active.paceEstimate(at: active.observedAt) == .onTrackToReset)
    }

    @Test func insufficientEvidenceKeepsExistingCopyAndHidesPace() {
        let single = snapshot(session: 60).recordingPace(previous: nil)
        #expect(single.paceEstimate(at: start) == .insufficientData)
        #expect(single.sessionPaceStatus(at: start) == .unavailable)
        #expect(single.sessionPaceAssessment(at: start)?.reason == .insufficientHistory)
        #expect(AppLanguage.english.resetLabel(for: single) == "RESETS")
        #expect(AppLanguage.english.resetText(for: single, now: start) == "Resets in 2h 0m")
        let tooShort = snapshot(session: 70, seconds: 60).recordingPace(previous: single)
        #expect(tooShort.paceEstimate(at: tooShort.observedAt) == .insufficientData)
        let tooSmall = series(session: [30, 30.2, 30.4])
        #expect(tooSmall.paceEstimate(at: tooSmall.observedAt) == .insufficientData)
    }

    @Test func decreasesAndChangedResetDatesStartNewSeries() {
        let previous = series(session: [60, 65, 70], weekly: [30, 31, 32])
        let decreased = snapshot(session: 1, weekly: 33, seconds: 900)
            .recordingPace(previous: previous)
        #expect(decreased.paceHistory?.session.count == 1)
        #expect(decreased.paceHistory?.weekly.count == 4)
        let changed = snapshot(session: 75, weekly: 33, seconds: 900, sessionReset: 10_000)
            .recordingPace(previous: previous)
        #expect(changed.paceHistory?.session.count == 1)
    }

    @Test func delayedJumpNeedsMoreEvidenceAndCannotGiveNegativePace() {
        let jump = series(session: [30, 30, 60])
        #expect(jump.paceEstimate(at: jump.observedAt) == .insufficientData)
        let correction = snapshot(session: 50, seconds: 900).recordingPace(previous: jump)
        #expect(correction.paceEstimate(at: correction.observedAt) == .insufficientData)
        let continued = snapshot(session: 65, seconds: 900).recordingPace(previous: jump)
        guard case .limitIn(let duration, _) = continued.paceEstimate(at: continued.observedAt) else {
            Issue.record("Expected a finite positive estimate after continued consumption")
            return
        }
        #expect(duration.isFinite && duration > 0)
    }

    @Test func primaryEstimateDoesNotSilentlySwitchToTheSecondaryQuota() {
        let sessionFirst = series(session: [60, 65, 70], weekly: [30, 31, 32])
        #expect(sessionFirst.paceEstimate(at: sessionFirst.observedAt) == .limitIn(1_800, quota: .session))
        let weeklyFirst = series(session: [30, 31, 32], weekly: [60, 65, 70])
        #expect(weeklyFirst.paceEstimate(at: weeklyFirst.observedAt) == .onTrackToReset)
        #expect(weeklyFirst.sessionPaceEstimate(at: weeklyFirst.observedAt) == .onTrackToReset)
        let neither = series(session: [10, 11, 12], weekly: [10, 11, 12],
                             sessionReset: 1_200, weeklyReset: 1_200)
        #expect(neither.paceEstimate(at: neither.observedAt) == .onTrackToReset)
    }

    @Test func sessionCopyOnlyAssessesTheSession() {
        let reading = series(session: [30, 30, 30], weekly: [30, 30.2, 30.4])
        #expect(reading.paceEstimate(at: reading.observedAt) == .onTrackToReset)
    }

    @Test func exhaustedQuotasSuppressPaceAndDetermineAvailability() {
        let sessionBlocked = snapshot(session: 100, weekly: 62, sessionReset: 43 * 60)
        #expect(sessionBlocked.paceEstimate(at: start) == nil)
        #expect(sessionBlocked.availability == .blocked(until: start.addingTimeInterval(43 * 60)))
        #expect(AppLanguage.english.resetText(for: sessionBlocked, now: start) == "Back in 43m")
        let weeklyBlocked = snapshot(session: 62, weekly: 100)
        #expect(weeklyBlocked.availabilityReset == start.addingTimeInterval(86_400))
        let both = snapshot(session: 100, weekly: 100, sessionReset: 43 * 60, weeklyReset: 52 * 3_600)
        #expect(both.availability == .blocked(until: start.addingTimeInterval(52 * 3_600)))
        #expect(AppLanguage.english.resetText(for: both, now: start) == "Back in 2d 4h")
        #expect(snapshot(session: 99.9, weekly: 99).availability == .available)
        let unknown = snapshot(session: 100, weekly: 100, weeklyReset: nil)
        #expect(unknown.availability == .blocked(until: nil))
        #expect(unknown.availabilityReset == nil)
    }

    @Test func cachedStaleAndUnavailableReadingsNeverShowPace() {
        let reading = series(session: [60, 65, 70])
        #expect(reading.paceEstimate(at: reading.observedAt.addingTimeInterval(601)) == nil)
        for source in [UsageSource.cached, .unavailable, .mock] {
            let cached = snapshot(session: 70, seconds: 900, source: source)
                .recordingPace(previous: reading)
            #expect(cached.paceHistory == reading.paceHistory)
            #expect(cached.paceEstimate(at: cached.observedAt) == nil)
        }
    }

    @Test func rejectsInvalidDuplicateAndOutOfOrderSamplesAndBoundsHistory() {
        let reading = series(session: [60, 65, 70])
        for (percent, seconds) in [(Double.nan, 900.0), (.infinity, 900), (-1, 900), (101, 900), (75, 300), (70, 600)] {
            let invalid = snapshot(session: percent, seconds: seconds).recordingPace(previous: reading)
            #expect(invalid.paceHistory == reading.paceHistory)
        }
        var bounded = snapshot(session: 30).recordingPace(previous: nil)
        for index in 1...200 {
            bounded = snapshot(session: 30, seconds: Double(index) * 30, sessionReset: 10_000)
                .recordingPace(previous: bounded)
        }
        #expect(bounded.paceHistory?.session.count == 121)
        #expect(bounded.paceHistory?.session.first?.timestamp == start.addingTimeInterval(2_400))
    }

    @Test func restartRetainsValidEvidenceUsingTheExistingCache() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = UsageSnapshotCache(fileURL: folder.appendingPathComponent("cache.json"))
        let reading = series(session: [60, 65, 70])
        try cache.save([reading])
        let loaded = try #require(cache.load()[.claude])
        #expect(loaded.paceHistory == reading.paceHistory)
        let next = snapshot(session: 75, seconds: 900).recordingPace(previous: loaded)
        #expect(next.paceEstimate(at: next.observedAt) == .limitIn(1_500, quota: .session))
        #expect(snapshot(session: 75, seconds: 900).recordingPace(previous: nil)
            .paceEstimate(at: start.addingTimeInterval(900)) == .insufficientData)
    }

    @Test func oldCacheWithoutPaceHistoryStillDecodes() throws {
        let encoded = try JSONEncoder().encode(snapshot(session: 30))
        #expect(try JSONDecoder().decode(ProviderUsageSnapshot.self, from: encoded).paceHistory == nil)
    }

    @Test func countdownAndPredictionFormattingAtBoundaries() {
        for (seconds, expected) in [(59.0, "0m"), (60, "1m"), (3_599, "59m"),
                                    (3_600, "1h 0m"), (3_660, "1h 1m"), (86_400, "1d")] {
            #expect(UsageResetFormatter.string(until: start.addingTimeInterval(seconds), relativeTo: start) == expected)
        }
        let predictions: [(Double, String)] = [(2_880, "~48m"), (8_400, "~2h 20m"),
                                               (3_540, "~1h"), (25_200, "~7h"),
                                               (187_200, "~2d 6h"), (20, "~1m")]
        for (seconds, expected) in predictions {
            #expect(UsagePaceFormatter.string(duration: seconds) == expected)
        }
        #expect(AppLanguage.spanish.resetText(for: snapshot(session: 100, sessionReset: 60), now: start)
            == "Disponible en 1m")
    }
}
