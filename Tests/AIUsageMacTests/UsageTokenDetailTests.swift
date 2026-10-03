import Foundation
import Testing
import AIUsageCore
@testable import AIUsageDesignSystem

struct UsageTokenDetailTests {
    private func totals(cost: Double?, hasUnpricedModels: Bool = false) -> WeeklyUsageTotals {
        WeeklyUsageTotals(
            inputTokens: 1_000_000,
            cachedInputTokens: 200_000,
            cacheWriteTokens: 0,
            outputTokens: 100_000,
            reasoningTokens: 20_000,
            equivalentCostUSD: cost,
            hasUnpricedModels: hasUnpricedModels,
            periodStart: Date(timeIntervalSince1970: 0),
            periodEnd: Date(timeIntervalSince1970: 7 * 86_400)
        )
    }

    @Test func tokenDetailContainsTheHiddenApiEquivalentAndApprovedCopy() {
        let english = tokenBreakdown(totals(cost: 12.34), language: .english)
        #expect(english.contains("API equivalent: ~$12.34"))
        #expect(english.contains(
            "Equivalent cost at API rates for the current weekly period. This is an estimate."
        ))
        let spanish = tokenBreakdown(totals(cost: 12.34), language: .spanish)
        #expect(spanish.contains("Equivalente API: ~$12.34"))
        #expect(spanish.contains(
            "Coste equivalente a tarifas API durante el periodo semanal actual. Estimación."
        ))
    }

    @Test func partialOrUnavailableCostIsExplainedWithoutPretendingItIsComplete() {
        let partial = tokenBreakdown(totals(cost: 12.34, hasUnpricedModels: true), language: .english)
        #expect(partial.contains("Some usage has no public price or model breakdown"))
        let missing = tokenBreakdown(totals(cost: nil, hasUnpricedModels: true), language: .english)
        #expect(missing.contains("API equivalent: N/A"))
        #expect(missing.contains("No public API rate or model breakdown"))
    }
}
