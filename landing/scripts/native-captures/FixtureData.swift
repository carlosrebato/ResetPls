import AIUsageCore
import Foundation

// The same synthetic readings drive every platform and menu state.
func landingSnapshots(now: Date) -> [ProviderUsageSnapshot] {
    UsageProviderID.allCases.enumerated().map { index, id in
        var previous: ProviderUsageSnapshot?
        for sample in 0..<3 {
            let percent = index == 0 ? Double(35 + sample) : Double(55 + sample * 10)
            let snapshot = ProviderUsageSnapshot(
                id: id,
                session: UsageWindow(usedPercent: percent, resetsAt: now.addingTimeInterval(index == 0 ? 8280 : 13320)),
                weekly: UsageWindow(usedPercent: index == 0 ? 36 : 19, resetsAt: now.addingTimeInterval(3 * 86400)),
                observedAt: now.addingTimeInterval(Double(sample - 2) * 720), source: .live, message: nil,
                weeklyTotals: WeeklyUsageTotals(inputTokens: 1_400_000, cachedInputTokens: 5_300_000, cacheWriteTokens: 300_000, outputTokens: 900_000, reasoningTokens: 100_000, equivalentCostUSD: 18.42, hasUnpricedModels: false, periodStart: now.addingTimeInterval(-6 * 86400), periodEnd: now))
            previous = snapshot.recordingPace(previous: previous)
        }
        return previous!
    }
}
