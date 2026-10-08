import AIUsageCore
import Foundation
import Testing

struct UsageTrendTests {
    private let date = Date(timeIntervalSince1970: 1_786_406_400)

    @Test func tokensAndQuotaNeverShareAChart() {
        let days = [
            UsageHistoryDay(date: date, claudeTokens: 1_000_000),
            UsageHistoryDay(date: date.addingTimeInterval(86_400), codexPercent: 50, claudeTokens: 500_000)
        ]
        let trend = UsageTrend(days: days, providers: [.claude, .codex], metric: .tokens)
        #expect(trend.metric == .tokens)
        #expect(trend.normalizedValue(for: days[1], provider: .claude) == 0.5)
        #expect(trend.value(for: days[1], provider: .codex) == nil)
        #expect(!trend.hasSeries(for: .codex))
    }

    @Test func emptyDaysDropToZeroWithoutBreakingTheLine() {
        let days = [
            UsageHistoryDay(date: date, claudeTokens: 100),
            UsageHistoryDay(date: date.addingTimeInterval(86_400)),
            UsageHistoryDay(date: date.addingTimeInterval(2 * 86_400), claudeTokens: 0),
            UsageHistoryDay(date: date.addingTimeInterval(3 * 86_400), claudeTokens: 200)
        ]
        let trend = UsageTrend(days: days, providers: [.claude], metric: .tokens)
        #expect(trend.value(for: days[1], provider: .claude) == 0)
        #expect(trend.normalizedValue(for: days[2], provider: .claude) == 0)
        #expect(trend.segments(for: .claude) == [[0, 1, 2, 3]])
        #expect(days[1].claudeTokens == nil)
    }

    @Test func onlyVisibleProvidersDetermineTheUnitAndScale() {
        let day = UsageHistoryDay(date: date, codexTokens: 1_000_000, claudeWeeklyPercent: 50)
        let quota = UsageTrend(days: [day], providers: [.claude])
        #expect(quota.metric == .percent)
        #expect(quota.normalizedValue(for: day, provider: .claude) == 0.5)
        #expect(quota.value(for: day, provider: .codex) == nil)

        let tokenDay = UsageHistoryDay(date: date, claudeTokens: 100, codexTokens: 1_000_000)
        let tokens = UsageTrend(days: [tokenDay], providers: [.claude], metric: .tokens)
        #expect(tokens.scaleMaximum == 100)
        #expect(tokens.normalizedValue(for: tokenDay, provider: .claude) == 1)
    }

    @Test func unknownWeeklyBalancesAreNotFabricatedAsResets() {
        let days = [
            UsageHistoryDay(date: date, codexWeeklyPercent: 0),
            UsageHistoryDay(date: date.addingTimeInterval(86_400)),
            UsageHistoryDay(date: date.addingTimeInterval(2 * 86_400), codexWeeklyPercent: 70)
        ]
        let trend = UsageTrend(days: days, providers: [.codex])
        #expect(trend.metric == .percent)
        #expect(trend.hasSeries(for: .codex))
        #expect(trend.segments(for: .codex) == [[0], [2]])
        #expect(trend.value(for: days[1], provider: .codex) == nil)
        #expect(trend.normalizedValue(for: days[2], provider: .codex) == 0.7)
    }

    @Test func allZeroTokenMeasurementsDoNotSwitchToQuota() {
        let day = UsageHistoryDay(date: date, claudePercent: 40, claudeTokens: 0)
        let trend = UsageTrend(days: [day], providers: [.claude], metric: .tokens)
        #expect(trend.metric == .tokens)
        #expect(trend.scaleMaximum > 0)
        #expect(trend.normalizedValue(for: day, provider: .claude) == 0)
    }

    @Test func emptyTodayDropsToZeroWithoutChangingStoredHistory() {
        let yesterday = date.addingTimeInterval(-86_400)
        let history = UsageHistory(days: [
            UsageHistoryDay(date: yesterday, claudeTokens: 100),
            UsageHistoryDay(date: date, claudeTokens: 200)
        ])
        let days = history.lastSevenDays(relativeTo: date, currentDayProviders: [])
        let trend = UsageTrend(days: days, providers: [.claude], metric: .tokens)
        #expect(trend.value(for: days.last!, provider: .claude) == 0)
        #expect(trend.segments(for: .claude) == [Array(0..<7)])
        #expect(history.days.last?.claudeTokens == 200)
    }

    @Test func noMeasurementsProduceNoSeries() {
        let day = UsageHistoryDay(date: date)
        let trend = UsageTrend(days: [day], providers: [.claude, .codex])
        #expect(!trend.hasSeries(for: .claude))
        #expect(trend.segments(for: .codex).isEmpty)
        #expect(trend.value(for: day, provider: .codex) == nil)
    }

    @Test func weeklyQuotaIsDefaultEvenWhenTokensExist() {
        let day = UsageHistoryDay(date: date, claudePercent: 87, claudeTokens: 100_000,
                                  claudeWeeklyPercent: 23, codexWeeklyPercent: 15)
        let trend = UsageTrend(days: [day], providers: [.claude, .codex])
        #expect(trend.metric == .percent)
        #expect(trend.scaleMaximum == 100)
        #expect(trend.value(for: day, provider: .claude) == 23)
        #expect(trend.value(for: day, provider: .codex) == 15)
    }

    @Test func resetsStayConnectedAndDoNotChangeTheScale() {
        let days = [82.0, 0, 8].enumerated().map { index, value in
            UsageHistoryDay(date: date.addingTimeInterval(Double(index) * 86_400),
                            claudeWeeklyPercent: value)
        }
        let trend = UsageTrend(days: days, providers: [.claude])
        #expect(trend.segments(for: .claude) == [[0, 1, 2]])
        #expect(trend.value(for: days[1], provider: .claude) == 0)
        #expect(trend.scaleMaximum == 100)
    }

    @Test func legacySessionPeaksAreNotWeeklyBalances() throws {
        let legacy = UsageHistory(days: [UsageHistoryDay(date: date, claudePercent: 87,
                                                        codexPercent: 40, claudeTokens: 500)])
        let restored = try JSONDecoder().decode(UsageHistory.self, from: JSONEncoder().encode(legacy))
        let quota = UsageTrend(days: restored.days, providers: [.claude, .codex])
        #expect(!quota.hasSeries(for: .claude))
        #expect(!quota.hasSeries(for: .codex))
        let tokens = UsageTrend(days: restored.days, providers: [.claude], metric: .tokens)
        #expect(tokens.value(for: restored.days[0], provider: .claude) == 500)
    }
}
