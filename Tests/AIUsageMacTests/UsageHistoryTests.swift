import AIUsageCore
import Foundation
import Testing

struct UsageHistoryTests {
    @Test func recordsDailyPeaksAndCalculatesTheCurrentStreak() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-usage-history-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let cache = UsageHistoryCache(fileURL: fileURL)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDay = Date(timeIntervalSince1970: 1_786_406_400)
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!

        _ = try cache.recording(
            [snapshot(provider: .claude, percent: 42, at: firstDay)],
            at: firstDay,
            calendar: calendar
        )
        _ = try cache.recording(
            [snapshot(provider: .claude, percent: 31, at: firstDay)],
            at: firstDay.addingTimeInterval(3_600),
            calendar: calendar
        )
        let history = try cache.recording(
            [snapshot(provider: .codex, percent: 20, at: secondDay)],
            at: secondDay,
            calendar: calendar
        )

        #expect(history.days.count == 2)
        #expect(history.days[0].claudePercent == 42)
        #expect(history.days[1].codexPercent == 20)
        #expect(history.currentStreak(relativeTo: secondDay, calendar: calendar) == 0)
        #expect(history.lastSevenDays(relativeTo: secondDay, calendar: calendar).count == 7)

        let visibleHistory = history.lastSevenDays(
            relativeTo: secondDay,
            currentDayProviders: [.codex],
            calendar: calendar
        )
        #expect(visibleHistory.last?.claudePercent == nil)
        #expect(visibleHistory.last?.claudeTokens == nil)
        #expect(visibleHistory.last?.codexPercent == 20)

        let activityHistory = try cache.applyingActivityDates(
            [firstDay],
            periodStart: firstDay,
            periodEnd: secondDay.addingTimeInterval(24 * 60 * 60),
            calendar: calendar
        )
        #expect(activityHistory.days[0].activity == true)
        #expect(activityHistory.days[1].activity == nil)
        // A positive quota balance is not evidence of activity on the second day.
        #expect(activityHistory.currentStreak(relativeTo: secondDay, calendar: calendar) == 0)

        let tokenHistory = try cache.applyingDailyTokens(
            [
                .claude: [firstDay: 1_250],
                .codex: [firstDay: 800, secondDay: 2_400]
            ],
            periodStart: firstDay,
            periodEnd: secondDay.addingTimeInterval(24 * 60 * 60),
            calendar: calendar
        )
        #expect(tokenHistory.days[0].claudeTokens == 1_250)
        #expect(tokenHistory.days[0].codexTokens == 800)
        #expect(tokenHistory.days[1].claudeTokens == nil)
        #expect(tokenHistory.days[1].codexTokens == 2_400)

        let rebuiltHistory = try cache.applyingDailyTokens(
            [.codex: [secondDay: 900]],
            periodStart: firstDay,
            periodEnd: secondDay.addingTimeInterval(24 * 60 * 60),
            calendar: calendar
        )
        #expect(rebuiltHistory.days[0].claudeTokens == 1_250)
        #expect(rebuiltHistory.days[0].codexTokens == 800)
        #expect(rebuiltHistory.days[1].codexTokens == 2_400)

        let growingCurrentDay = try cache.applyingDailyTokens(
            [.codex: [firstDay: 1_200, secondDay: 3_000]],
            periodStart: firstDay,
            periodEnd: secondDay.addingTimeInterval(24 * 60 * 60),
            calendar: calendar
        )
        #expect(growingCurrentDay.days[0].codexTokens == 1_200)
        #expect(growingCurrentDay.days[1].codexTokens == 3_000)

        let shrinkingCurrentDay = try cache.applyingDailyTokens(
            [.codex: [secondDay: 1_000]],
            periodStart: firstDay,
            periodEnd: secondDay.addingTimeInterval(24 * 60 * 60),
            calendar: calendar
        )
        #expect(shrinkingCurrentDay.days[1].codexTokens == 3_000)

        let emptyScanHistory = try cache.applyingDailyTokens(
            [.claude: [:], .codex: [:]],
            periodStart: firstDay,
            periodEnd: secondDay.addingTimeInterval(24 * 60 * 60),
            calendar: calendar
        )
        #expect(emptyScanHistory.days[0].claudeTokens == 1_250)
        #expect(emptyScanHistory.days[0].codexTokens == 1_200)
        #expect(emptyScanHistory.currentStreak(relativeTo: secondDay, calendar: calendar) == 2)
        #expect(emptyScanHistory.days[1].codexTokens == 3_000)
    }

    @Test func emptyActivityScansPreservePositiveEvidence() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-usage-history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let day = Calendar.current.startOfDay(for: .now)
        let end = day.addingTimeInterval(3_600)
        let cache = UsageHistoryCache(fileURL: fileURL)
        _ = try cache.applyingActivityDates([day], periodStart: day, periodEnd: end)
        let missing = try cache.applyingActivityDates([], periodStart: day, periodEnd: end)
        #expect(missing.days.first?.activity == true)
        #expect(missing.currentStreak(relativeTo: end) == 1)
    }

    @Test func explicitZeroTokensRemainDistinctFromMissingMeasurements() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-usage-history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let day = Calendar.current.startOfDay(for: .now)
        let cache = UsageHistoryCache(fileURL: fileURL)
        let history = try cache.applyingDailyTokens(
            [.claude: [day: 0]], periodStart: day, periodEnd: day.addingTimeInterval(3_600)
        )
        #expect(history.days.first?.claudeTokens == 0)
        #expect(history.days.first?.codexTokens == nil)
        #expect(history.currentStreak(relativeTo: day) == 0)
    }

    @Test func missingLiveQuotaIsNotRecordedAsZero() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-usage-history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let cache = UsageHistoryCache(fileURL: fileURL)
        let now = Date.now
        let missing = ProviderUsageSnapshot(
            id: .claude,
            session: UsageWindow(usedPercent: nil, resetsAt: nil),
            weekly: UsageWindow(usedPercent: nil, resetsAt: nil),
            observedAt: now, source: .live, message: nil
        )
        let history = try cache.recording([missing], at: now)
        #expect(history.days.first?.claudePercent == nil)
    }

    private func snapshot(
        provider: UsageProviderID,
        percent: Double,
        at date: Date
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            id: provider,
            session: UsageWindow(usedPercent: percent, resetsAt: nil),
            weekly: UsageWindow(usedPercent: percent, resetsAt: nil),
            observedAt: date,
            source: .live,
            message: nil
        )
    }
}
