import SwiftUI
import AIUsageCore

@MainActor final class UsageStore: ObservableObject {
    @Published var snapshots: [ProviderUsageSnapshot]
    @Published var history: UsageHistory
    @Published var isRefreshing = false
    init() {
        let now = Date.now
        snapshots = landingSnapshots(now: now)
        let claude = [700_000,100_000,200_000,2_200_000,1_400_000,2_100_000,350_000]
        let codex = [1_000_000,100_000,120_000,750_000,650_000,950_000,340_000]
        history = UsageHistory(days: (0..<7).map { i in
            UsageHistoryDay(date: Calendar.current.startOfDay(for: now.addingTimeInterval(Double(i-6)*86400)), claudeTokens: claude[i], codexTokens: codex[i])
        })
    }
    func setAutomaticPollingEnabled(_ enabled: Bool) {}
}
@MainActor final class ProviderSelectionStore: ObservableObject {
    func filtering(_ snapshots: [ProviderUsageSnapshot]) -> [ProviderUsageSnapshot] { snapshots }
}
enum AppPreferenceKey {
    static let automaticRefresh = "automaticRefresh"
    static let showResetTimesInMenuBar = "showResetTimesInMenuBar"
    static let menuBarExpanded = "menuBarExpanded"
    static let language = AppLanguage.preferenceKey
}
