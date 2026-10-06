import AIUsageCore
import AIUsageProviderServices
import Foundation
import WidgetKit

@MainActor
final class IOSUsageStore: ObservableObject {
    @Published private(set) var snapshots: [ProviderUsageSnapshot] = []
    @Published private(set) var states: [UsageProviderID: ProviderDataState] = [
        .claude: .setupRequired,
        .codex: .setupRequired
    ]
    @Published private(set) var messages: [UsageProviderID: String] = [:]
    @Published private(set) var history: UsageHistory
    @Published private(set) var isRefreshing = false
    @Published private(set) var authenticatingProviders: Set<UsageProviderID> = []
    @Published var isDemoMode = ProcessInfo.processInfo.arguments.contains("--app-review-demo")

    private let cache: LastKnownCache
    private let historyCache: UsageHistoryCache
    private let statusCache: ProviderStatusCache
    private var lastRefresh: Date?
    private let refresher: SharedUsageRefresh

    /// Explicit allowlist: never export adapter responses, credentials, account
    /// identifiers, messages or conversation history with a usage diagnostic.
    func diagnosticReport(at date: Date = .now) -> String {
        struct Report: Encodable {
            struct Provider: Encodable {
                let provider: String
                let state: String
                let source: String?
                let observedAt: Date?
                let session: UsageWindow?
                let weekly: UsageWindow?
                let hasTokenTotals: Bool
            }
            let generatedAt: Date
            let version: String
            let build: String
            let operatingSystem: String
            let providers: [Provider]
            let refreshEvidence: [UsageProviderID: UsageRefreshEvidence]
            let backgroundRefreshRequestedAt: Date?
            let backgroundRefreshScheduled: Bool?
            let backgroundRefreshScheduleError: Int?
        }
        let report = Report(
            generatedAt: date,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            providers: UsageProviderID.allCases.map { provider in
                let snapshot = snapshots.first { $0.id == provider }
                return Report.Provider(
                    provider: provider.rawValue,
                    state: (states[provider] ?? .setupRequired).rawValue,
                    source: snapshot?.source.rawValue,
                    observedAt: snapshot?.observedAt,
                    session: snapshot?.session, weekly: snapshot?.weekly,
                    hasTokenTotals: snapshot?.weeklyTotals != nil
                )
            },
            refreshEvidence: refresher.evidenceCache.load(),
            backgroundRefreshRequestedAt: UserDefaults.standard.object(forKey: "iosBackgroundRefreshRequestedAt") as? Date,
            backgroundRefreshScheduled: UserDefaults.standard.object(forKey: "iosBackgroundRefreshScheduled") as? Bool,
            backgroundRefreshScheduleError: UserDefaults.standard.object(forKey: "iosBackgroundRefreshScheduleError") as? Int
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report), let text = String(data: data, encoding: .utf8)
        else { return "ResetPls diagnostic could not be generated." }
        return text
    }

    init(
        claude: any DirectUsageAdapter = ClaudeDirectAdapter(),
        codex: any DirectUsageAdapter = CodexDirectAdapter(),
        cache: LastKnownCache? = nil,
        historyCache: UsageHistoryCache? = nil,
        statusCache: ProviderStatusCache? = nil
    ) {
        let resolvedCache = cache ?? LastKnownCache()
        self.cache = resolvedCache
        self.historyCache = historyCache ?? UsageHistoryCache()
        self.statusCache = statusCache ?? ProviderStatusCache(
            fileURL: resolvedCache.fileURL.deletingLastPathComponent()
                .appendingPathComponent("provider-status.json")
        )
        refresher = SharedUsageRefresh(claude: claude, codex: codex, cache: resolvedCache,
            historyCache: self.historyCache, statusCache: self.statusCache)
        history = self.historyCache.load()
        if isDemoMode {
            applyDemo()
        } else {
            restoreCachedSnapshots()
        }
    }

    /// Collect real observations while the dashboard is active, using the same
    /// ordinary cadence as Mac. Updating the UI clock alone is not a refresh.
    func refreshIfDue(at date: Date) async {
        let interval = TimeInterval(PollingPolicy.interval(
            for: .normal, consecutiveFailures: 0
        ).components.seconds)
        guard !isDemoMode, !isRefreshing,
              lastRefresh.map({ date.timeIntervalSince($0) >= interval }) ?? true else { return }
        await refresh()
    }

    func refresh(force: Bool = false) async {
        if isDemoMode {
            applyDemo()
            return
        }
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 60 { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefresh = .now
        }

        do {
            let result = try await refresher.refresh(context: "foreground", force: force)
            snapshots = result.snapshots.sorted { $0.id.rawValue < $1.id.rawValue }
            states.merge(result.states) { _, new in new }
            messages = result.messages
            for snapshot in snapshots where states[snapshot.id] == .live {
                ProviderVisibilityPreferences.setVisible(true, for: snapshot.id)
            }
            history = historyCache.load()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Cancellation/persistence errors are not provider failures.
            // Keep the last valid value and the existing connection state.
        }
    }

    func signIn(_ provider: UsageProviderID) async {
        await signIn(provider) {
            try await ProviderWebAuthentication.shared.signIn(provider)
        }
    }

    func signIn(
        _ provider: UsageProviderID,
        authenticate: @escaping @MainActor () async throws -> Void
    ) async {
        let previousSnapshot = snapshots.first { $0.id == provider }
        let previousState = states[provider] ?? .setupRequired
        let previousMessage = messages[provider]
        authenticatingProviders.insert(provider)
        snapshots.removeAll { $0.id == provider }
        messages[provider] = nil
        try? cache.save(snapshots)
        persistProviderStates()
        defer { authenticatingProviders.remove(provider) }

        do {
            try await authenticate()
            await refresh(force: true)
        } catch {
            if ProviderWebAuthentication.isCancellation(error) {
                if let previousSnapshot { replace(previousSnapshot) }
                states[provider] = previousState
                messages[provider] = previousMessage
                try? cache.save(snapshots)
                persistProviderStates()
                return
            }
            states[provider] = previousState == .setupRequired ? .setupRequired : .reauthRequired
            messages[provider] = error.localizedDescription
            persistProviderStates()
        }
    }

    func signOut(_ provider: UsageProviderID) async {
        do {
            try await ProviderAccounts.shared.signOut(provider)
            snapshots.removeAll { $0.id == provider }
            ProviderVisibilityPreferences.setVisible(false, for: provider)
            states[provider] = .setupRequired
            messages[provider] = nil
            try? cache.save(snapshots)
            persistProviderStates()
        } catch {
            messages[provider] = error.localizedDescription
        }
    }

    func setDemoMode(_ enabled: Bool) {
        isDemoMode = enabled
        if enabled {
            applyDemo()
        } else {
            snapshots = []
            states = [.claude: .setupRequired, .codex: .setupRequired]
            messages = [:]
        }
    }

    private func replace(_ snapshot: ProviderUsageSnapshot) {
        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
            snapshots.sort { $0.id.rawValue < $1.id.rawValue }
        }
    }

    private func restoreCachedSnapshots() {
        snapshots = cache.load().values
            .map { snapshot in
                ProviderUsageSnapshot(
                    id: snapshot.id,
                    session: snapshot.session,
                    weekly: snapshot.weekly,
                    observedAt: snapshot.observedAt,
                    source: .cached,
                    message: snapshot.message,
                    weeklyTotals: snapshot.weeklyTotals,
                    paceHistory: snapshot.paceHistory
                )
            }
            .sorted { $0.id.rawValue < $1.id.rawValue }

        for snapshot in snapshots {
            ProviderVisibilityPreferences.setVisible(true, for: snapshot.id)
            states[snapshot.id] = .cached
            messages[snapshot.id] = snapshot.message
        }
    }

    private func persistProviderStates() {
        try? statusCache.save(states)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func applyDemo() {
        let now = Date.now
        snapshots = [
            ProviderUsageSnapshot(
                id: .claude,
                session: UsageWindow(usedPercent: 28, resetsAt: now.addingTimeInterval(2 * 3600)),
                weekly: UsageWindow(usedPercent: 43, resetsAt: now.addingTimeInterval(4 * 86_400)),
                observedAt: now,
                source: .mock,
                message: "App Review demo"
            ),
            ProviderUsageSnapshot(
                id: .codex,
                session: UsageWindow(usedPercent: 64, resetsAt: now.addingTimeInterval(90 * 60)),
                weekly: UsageWindow(usedPercent: 37, resetsAt: now.addingTimeInterval(5 * 86_400)),
                observedAt: now,
                source: .mock,
                message: "App Review demo"
            )
        ]
        states = [.claude: .live, .codex: .live]
        messages = [:]
        history = Self.demoHistory(relativeTo: now)
    }

    private static func demoHistory(relativeTo now: Date) -> UsageHistory {
        let calendar = Calendar.current
        let claude = [22.0, 31, 19, 46, 38, 51, 43]
        let codex = [35.0, 28, 44, 32, 57, 49, 64]
        let days = (-6...0).compactMap { offset -> UsageHistoryDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            let index = offset + 6
            return UsageHistoryDay(
                date: calendar.startOfDay(for: date),
                claudePercent: claude[index],
                codexPercent: codex[index],
                activity: true
            )
        }
        return UsageHistory(days: days)
    }
}
