import AIUsageCore
import Foundation
import Testing
@testable import AIUsageMacServices

struct UsageReviewReproductionTests {
    @Test func lateTokensMustUpdateYesterdayAfterMidnight() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("review-history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = calendar.startOfDay(for: Date.now.addingTimeInterval(-86400))
        let today = calendar.date(byAdding: .day, value: 1, to: yesterday)!
        let cache = UsageHistoryCache(fileURL: file)
        _ = try cache.applyingDailyTokens([.codex: [yesterday: 1000]], periodStart: yesterday, periodEnd: today.addingTimeInterval(-300), calendar: calendar)
        let updated = try cache.applyingDailyTokens([.codex: [yesterday: 1500, today: 100]], periodStart: yesterday, periodEnd: today.addingTimeInterval(1200), calendar: calendar)
        #expect(updated.days.first { $0.date == yesterday }?.codexTokens == 1500)
    }

    @Test func unchangedQuotaMustNotProveDailyActivity() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("review-streak-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = calendar.startOfDay(for: Date.now.addingTimeInterval(-86400))
        let second = calendar.date(byAdding: .day, value: 1, to: first)!
        let cache = UsageHistoryCache(fileURL: file)
        for day in [first, second] {
            let snapshot = ProviderUsageSnapshot(id: .codex, session: UsageWindow(usedPercent: nil, resetsAt: nil), weekly: UsageWindow(usedPercent: 40, resetsAt: nil), observedAt: day, source: .live, message: nil)
            _ = try cache.recording([snapshot], at: day, calendar: calendar)
        }
        let history = try cache.applyingActivityDates([first], periodStart: first, periodEnd: second.addingTimeInterval(3600), calendar: calendar)
        #expect(history.currentStreak(relativeTo: second, calendar: calendar) == 0)
    }

    @Test func weeklyQueryMustRespectMovingPeriodStart() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("review-home-\(UUID())")
        defer { try? FileManager.default.removeItem(at: home) }
        let file = home.appendingPathComponent(".claude/projects/demo/session.jsonl")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let start = Date.now.addingTimeInterval(-7200)
        let eventTime = ISO8601DateFormatter().string(from: start.addingTimeInterval(600))
        let line = "{\"timestamp\":\"\(eventTime)\",\"type\":\"assistant\",\"message\":{\"id\":\"boundary\",\"model\":\"claude-sonnet-5\",\"usage\":{\"input_tokens\":100,\"output_tokens\":50}}}\n"
        try Data(line.utf8).write(to: file)
        let reader = LocalUsageMetricsReader(homeDirectory: home, refreshInterval: 0)
        let first = await reader.weeklyTotals(for: .claude, periodStart: start, periodEnd: .now)
        #expect(first?.totalTokens == 150)
        let later = await reader.weeklyTotals(for: .claude, periodStart: start.addingTimeInterval(1200), periodEnd: .now)
        #expect(later == nil)
    }
}
