import AIUsageCore
import Darwin
import Foundation

/// Used by the iOS app and its extensions. A file lock covers network/token
/// rotation AND cache writes across processes, not just actors in one process.
public actor SharedUsageRefresh {
    public static let shared = SharedUsageRefresh()
    private let adapters: [UsageProviderID: any DirectUsageAdapter]
    private let cache: LastKnownCache
    private let statusCache: ProviderStatusCache
    private let historyCache: UsageHistoryCache
    public nonisolated let evidenceCache: UsageRefreshEvidenceCache

    public struct Result: Sendable {
        public let snapshots: [ProviderUsageSnapshot]
        public let states: [UsageProviderID: ProviderDataState]
        public let messages: [UsageProviderID: String]
        public let didRefresh: Bool
    }

    public init(claude: any DirectUsageAdapter = ClaudeDirectAdapter(),
                codex: any DirectUsageAdapter = CodexDirectAdapter(),
                cache: LastKnownCache = LastKnownCache(),
                historyCache: UsageHistoryCache = UsageHistoryCache(),
                statusCache: ProviderStatusCache? = nil) {
        adapters = [.claude: claude, .codex: codex]
        self.cache = cache
        self.historyCache = historyCache
        let directory = cache.fileURL.deletingLastPathComponent()
        self.statusCache = statusCache ?? ProviderStatusCache(fileURL: directory.appendingPathComponent("provider-status.json"))
        evidenceCache = UsageRefreshEvidenceCache(fileURL: directory.appendingPathComponent("refresh-evidence.json"))
    }

    public func refresh(context: String, force: Bool = false, at now: Date = .now) async throws -> Result {
        let directory = cache.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let lease = RefreshLease(url: directory.appendingPathComponent("refresh.lock")) else {
            return savedResult()
        }
        defer { lease.release() }
        var values = cache.load()
        var states = statusCache.load().mapValues(\.state)
        var evidence = evidenceCache.load()
        var messages: [UsageProviderID: String] = [:]
        var didRefresh = false
        for provider in UsageProviderID.allCases {
            try Task.checkCancellation()
            let previous = evidence[provider]
            // Respect rate-limit/backoff across extension processes. A forced
            // foreground refresh may bypass normal cadence, not provider limits.
            if let retryAt = previous?.retryAt, now < retryAt,
               !force || previous?.errorCode == "rate_limited" { continue }
            if let last = previous?.attemptedAt,
               !force, now.timeIntervalSince(last) < 300 { continue }
            didRefresh = true
            evidence[provider] = UsageRefreshEvidence(attemptedAt: now,
                succeededAt: previous?.succeededAt, failedAt: previous?.failedAt, context: context)
            try evidenceCache.save(evidence)
            do {
                let snapshot = try await adapters[provider]!.fetchSnapshot()
                try Task.checkCancellation()
                values[provider] = snapshot.recordingPace(previous: values[provider])
                states[provider] = .live
                evidence[provider] = UsageRefreshEvidence(attemptedAt: now,
                    succeededAt: snapshot.observedAt, context: context)
            } catch {
                if Task.isCancelled || error is CancellationError { throw CancellationError() }
                let hasValue = values[provider] != nil
                let direct = error as? DirectUsageError
                let oauth = error as? ProviderOAuthError
                let requiresAuth = direct?.requiresReauthentication == true
                    || oauth == .reauthenticationRequired || oauth == .missingRefreshToken
                let isRateLimited: Bool
                if case .rateLimited? = direct { isRateLimited = true } else { isRateLimited = false }
                states[provider] = requiresAuth ? (direct == .notAuthenticated && !hasValue ? .setupRequired : .reauthRequired)
                    : (hasValue ? .stale : .temporarilyUnavailable)
                if let old = values[provider] {
                    values[provider] = ProviderUsageSnapshot(id: old.id, session: old.session,
                        weekly: old.weekly, observedAt: old.observedAt, source: .cached,
                        message: old.message, weeklyTotals: old.weeklyTotals, paceHistory: old.paceHistory)
                }
                messages[provider] = error.localizedDescription
                let finished = Date.now
                evidence[provider] = UsageRefreshEvidence(attemptedAt: now,
                    succeededAt: previous?.succeededAt, failedAt: finished,
                    retryAt: finished.addingTimeInterval(max(direct?.retryAfter ?? (isRateLimited ? 300 : 60), 60)),
                    context: context, errorCode: isRateLimited ? "rate_limited"
                        : requiresAuth ? "authentication" : "request_failed")
            }
            try cache.save(Array(values.values))
            try statusCache.save(states)
            try evidenceCache.save(evidence)
        }
        if didRefresh { _ = try historyCache.recording(Array(values.values), at: now) }
        return Result(snapshots: Array(values.values), states: states, messages: messages, didRefresh: didRefresh)
    }

    private func savedResult() -> Result {
        Result(snapshots: Array(cache.load().values), states: statusCache.load().mapValues(\.state),
               messages: [:], didRefresh: false)
    }
}

private final class RefreshLease {
    private var descriptor: Int32
    init?(url: URL) {
        descriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
    }
    func release() {
        guard descriptor >= 0 else { return }
        flock(descriptor, LOCK_UN)
        close(descriptor)
        descriptor = -1
    }
    deinit { release() }
}
