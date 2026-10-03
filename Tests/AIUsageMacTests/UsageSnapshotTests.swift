import Foundation
import Testing
@testable import AIUsageCore

struct UsageSnapshotTests {
    @Test func widgetFallsBackToCachedProvidersWhenVisibilityWasNeverInitialized() {
        let suite = "ProviderVisibility.widgetFallback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let displayed = ProviderVisibilityPreferences.displayedProviders(
            cachedProviders: [.codex],
            in: defaults
        )

        #expect(displayed == [.codex])
    }

    @Test func explicitVisibilityStillWinsOverCachedWidgetProviders() {
        let suite = "ProviderVisibility.widgetSelection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        ProviderVisibilityPreferences.setVisible(true, for: .claude, in: defaults)

        let displayed = ProviderVisibilityPreferences.displayedProviders(
            cachedProviders: [.claude, .codex],
            in: defaults
        )

        #expect(displayed == [.claude])
    }

    @Test func connectedEmptySelectionIsRecoveredOnceWithoutOverridingLaterChoices() {
        let suite = "ProviderVisibility.recovery.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        ProviderVisibilityPreferences.migrateIfNeeded(onboardingCompleted: false, in: defaults)

        let recovered = ProviderVisibilityPreferences.recoverConnectedProvidersIfEmpty(
            onboardingCompleted: true, connectedProviders: [.claude], in: defaults
        )
        #expect(recovered == [.claude])
        #expect(ProviderVisibilityPreferences.isVisible(.claude, in: defaults))
        ProviderVisibilityPreferences.setVisible(false, for: .claude, in: defaults)
        #expect(ProviderVisibilityPreferences.recoverConnectedProvidersIfEmpty(
            onboardingCompleted: true, connectedProviders: [.claude], in: defaults
        ).isEmpty)
        #expect(!ProviderVisibilityPreferences.isVisible(.claude, in: defaults))
    }

    @Test func freshOnboardingSelectsNoAssistantUntilTheUserChoosesOne() {
        let suite = "ProviderVisibility.fresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        ProviderVisibilityPreferences.migrateIfNeeded(
            onboardingCompleted: false,
            in: defaults
        )

        #expect(!ProviderVisibilityPreferences.isVisible(.claude, in: defaults))
        #expect(!ProviderVisibilityPreferences.isVisible(.codex, in: defaults))
    }

    @Test func existingUsersKeepBothAssistantsVisibleDuringMigration() {
        let suite = "ProviderVisibility.existing.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        ProviderVisibilityPreferences.migrateIfNeeded(
            onboardingCompleted: true,
            in: defaults
        )

        #expect(ProviderVisibilityPreferences.isVisible(.claude, in: defaults))
        #expect(ProviderVisibilityPreferences.isVisible(.codex, in: defaults))
    }

    @Test func anExplicitAssistantChoiceSurvivesMigration() {
        let suite = "ProviderVisibility.choice.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        ProviderVisibilityPreferences.setVisible(true, for: .claude, in: defaults)
        ProviderVisibilityPreferences.setVisible(false, for: .codex, in: defaults)

        ProviderVisibilityPreferences.migrateIfNeeded(
            onboardingCompleted: true,
            in: defaults
        )

        #expect(ProviderVisibilityPreferences.isVisible(.claude, in: defaults))
        #expect(!ProviderVisibilityPreferences.isVisible(.codex, in: defaults))
    }

    @Test func severityThresholdsMatchTheExistingDesign() {
        #expect(UsageSeverity.forPercent(nil) == .unavailable)
        #expect(UsageSeverity.forPercent(69) == .normal)
        #expect(UsageSeverity.forPercent(70) == .warning)
        #expect(UsageSeverity.forPercent(84.9) == .warning)
        #expect(UsageSeverity.forPercent(85) == .critical)
    }

    @Test func snapshotUsesTheMostConstrainedWindow() {
        let now = Date(timeIntervalSince1970: 1000)
        let snapshot = ProviderUsageSnapshot(
            id: .claude,
            session: UsageWindow(usedPercent: 42, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 88, resetsAt: nil),
            observedAt: now,
            source: .live,
            message: nil
        )

        #expect(snapshot.highestPercent == 88)
        #expect(snapshot.severity == .critical)
    }

    @Test func freshnessBecomesStaleAfterTenMinutes() {
        let observedAt = Date(timeIntervalSince1970: 1000)
        let snapshot = ProviderUsageSnapshot(
            id: .codex,
            session: UsageWindow(usedPercent: 20, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 30, resetsAt: nil),
            observedAt: observedAt,
            source: .live,
            message: nil
        )

        #expect(!snapshot.isStale(at: observedAt.addingTimeInterval(599)))
        #expect(snapshot.isStale(at: observedAt.addingTimeInterval(601)))
        #expect(!snapshot.isStale(at: observedAt.addingTimeInterval(-60)))
        #expect(snapshot.isStale(at: observedAt.addingTimeInterval(-61)))
    }

    @Test func codexUsesWeeklyWindowAsPrimaryDisplayWhenSessionIsUnavailable() {
        let weeklyReset = Date(timeIntervalSince1970: 2000)
        let snapshot = ProviderUsageSnapshot(
            id: .codex,
            session: UsageWindow(usedPercent: nil, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 42, resetsAt: weeklyReset),
            observedAt: Date(timeIntervalSince1970: 1000),
            source: .live,
            message: nil
        )

        #expect(snapshot.primaryDisplayWindow == snapshot.weekly)
    }

    @Test func freshnessNeverReportsAnUpdateFromTheFuture() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = snapshot(observedAt: now.addingTimeInterval(60), source: .live)

        let freshness = UsageFreshness(snapshots: [snapshot], now: now)

        #expect(freshness.kind == .live)
        #expect(freshness.date == now)
    }

    @Test func freshnessSurfacesTheOldestCachedProvider() {
        let now = Date(timeIntervalSince1970: 2_000)
        let live = snapshot(observedAt: now, source: .live, provider: .claude)
        let cached = snapshot(
            observedAt: now.addingTimeInterval(-120),
            source: .cached,
            provider: .codex
        )

        let freshness = UsageFreshness(snapshots: [live, cached], now: now)

        #expect(freshness.kind == .cached)
        #expect(freshness.date == cached.observedAt)
    }

    @Test func resetCountdownUsesDaysAfterTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(
            UsageResetFormatter.string(
                until: now.addingTimeInterval((5 * 24 + 13) * 3_600),
                relativeTo: now
            ) == "5d 13h"
        )
        #expect(
            UsageResetFormatter.string(
                until: now.addingTimeInterval(24 * 3_600),
                relativeTo: now
            ) == "1d"
        )
        #expect(
            UsageResetFormatter.string(
                until: now.addingTimeInterval(4 * 3_600 + 27 * 60),
                relativeTo: now
            ) == "4h 27m"
        )
    }

    @Test func weeklyTotalsDecodeCachesWrittenBeforeUnclassifiedTokensExisted() throws {
        let data = Data(
            #"{"inputTokens":100,"cachedInputTokens":20,"cacheWriteTokens":5,"outputTokens":10,"reasoningTokens":2,"equivalentCostUSD":0.01,"hasUnpricedModels":false,"periodStart":0,"periodEnd":100}"#.utf8
        )

        let totals = try JSONDecoder().decode(WeeklyUsageTotals.self, from: data)

        #expect(totals.unclassifiedTokens == nil)
        #expect(totals.totalTokens == 135)
    }

    @Test func providerStatusCacheSharesOnlySemanticWidgetState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderStatusCacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ProviderStatusCache(
            fileURL: directory.appendingPathComponent("provider-status.json")
        )
        let recordedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try cache.save([
            .claude: .live,
            .codex: .reauthRequired
        ], at: recordedAt)

        let restored = cache.load()
        #expect(restored[.claude] == ProviderStatusRecord(
            provider: .claude,
            state: .live,
            recordedAt: recordedAt
        ))
        #expect(restored[.codex] == ProviderStatusRecord(
            provider: .codex,
            state: .reauthRequired,
            recordedAt: recordedAt
        ))
    }

    private func snapshot(
        observedAt: Date,
        source: UsageSource,
        provider: UsageProviderID = .claude
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            id: provider,
            session: UsageWindow(usedPercent: 20, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 30, resetsAt: nil),
            observedAt: observedAt,
            source: source,
            message: nil
        )
    }
}
