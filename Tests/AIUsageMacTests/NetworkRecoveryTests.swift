import AIUsageCore
import AIUsageProviderServices
import Foundation
import Testing
@testable import AIUsageMacServices

private final class RecoveryClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date.now
    func now() -> Date { lock.withLock { value } }
    func advance(_ seconds: TimeInterval) { lock.withLock { value.addTimeInterval(seconds) } }
}

private actor RecoveryConnector: UsageConnector {
    nonisolated let providerID: UsageProviderID
    private var failures: [UsageConnectorError]
    private(set) var calls = 0
    private(set) var interactions: [Bool] = []
    private var holdFirst: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    init(_ provider: UsageProviderID = .codex, failures: [UsageConnectorError] = [], holdFirst: Bool = false) {
        providerID = provider
        self.failures = failures
        self.holdFirst = holdFirst
    }
    func fetchSnapshot(allowInteraction: Bool) async throws -> ProviderUsageSnapshot {
        calls += 1
        interactions.append(allowInteraction)
        if holdFirst && calls == 1 { await withCheckedContinuation { continuation = $0 } }
        if !failures.isEmpty { throw failures.removeFirst() }
        return ProviderUsageSnapshot(id: providerID,
            session: UsageWindow(usedPercent: nil, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 38, resetsAt: .now.addingTimeInterval(86400)),
            observedAt: .now, source: .live, message: nil)
    }
    func started() -> Bool { continuation != nil }
    func release() { continuation?.resume(); continuation = nil }
}

private struct RecoveryAdapter: DirectUsageAdapter {
    let providerID = UsageProviderID.codex
    let error: DirectUsageError
    func fetchSnapshot() async throws -> ProviderUsageSnapshot { throw error }
}

private struct CancelledRecoveryConnector: UsageConnector {
    let providerID = UsageProviderID.codex
    func fetchSnapshot(allowInteraction: Bool) async throws -> ProviderUsageSnapshot { throw CancellationError() }
}

struct NetworkRecoveryTests {
    @Test @MainActor func recoveryAndManualRefreshDoNotInterfereWithAnActiveReconnection() async {
        let connector = RecoveryConnector(failures: [.networkUnavailable])
        let store = makeStore(connector)
        await store.refresh(force: false, allowInteraction: false)
        store.beginReconnection(for: .codex)
        await store.recoverAfterNetworkChange()
        await store.refreshManually()
        #expect(await connector.calls == 1)
        #expect(store.connectionStatuses.first { $0.id == .codex }?.phase == .checking)
    }

    @Test @MainActor func automaticRecoveryIsCancelledIfDisabledWhileWaitingForAnActiveFetch() async {
        let connector = RecoveryConnector(failures: [.networkUnavailable], holdFirst: true)
        let store = makeStore(connector)
        let first = Task { await store.refresh(force: false, allowInteraction: false) }
        while !(await connector.started()) { await Task.yield() }
        let recovery = Task { await store.recoverAfterNetworkChange() }
        store.setAutomaticPollingEnabled(false)
        await connector.release()
        await first.value
        await recovery.value
        #expect(await connector.calls == 1)
    }

    @Test @MainActor func targetedManualRetryDoesNotPollTheOtherProvider() async {
        let codex = RecoveryConnector()
        let claude = RecoveryConnector(.claude)
        let store = makeStore(codex, claude: claude)
        await store.refresh(force: false, allowInteraction: false)
        await store.refreshManually(provider: .codex)
        #expect(await codex.calls == 2)
        #expect(await claude.calls == 1)
    }
    @Test @MainActor func cancelledFetchDoesNotCountAsANetworkOrAuthenticationFailure() async throws {
        let store = makeStore(CancelledRecoveryConnector())
        await store.refresh(force: true, allowInteraction: false)
        #expect(!store.isRefreshing)
        #expect(store.snapshots.first { $0.id == .codex }?.weekly.usedPercent == 37)
        let diagnostic = String(decoding: try store.diagnosticReportData(), as: UTF8.self)
        #expect(!diagnostic.contains("reauthRequired"))
        #expect(diagnostic.contains("\"consecutiveFailures\" : 0"))
    }
    @Test func pathTransitionsIgnoreInitialOnlineAndDuplicateNotifications() {
        var transition = NetworkRecoveryTransition()
        let results = [true, true, false, false, true, true].map {
            transition.update(isConnected: $0)
        }
        #expect(results == [false, false, false, false, true, false])
    }

    @Test @MainActor func genuineNetworkFailureRecoversBeforeTheClientDeadline() async {
        let connector = RecoveryConnector(failures: [.networkUnavailable])
        let store = makeStore(connector)
        await store.refresh(force: false, allowInteraction: false)
        #expect(store.snapshots.first { $0.id == .codex }?.weekly.usedPercent == 37)
        await store.refresh(force: false, allowInteraction: false)
        #expect(await connector.calls == 1)
        await store.recoverAfterNetworkChange()
        #expect(await connector.calls == 2)
        #expect(await connector.interactions == [false, false])
        #expect(store.snapshots.first { $0.id == .codex }?.source == .live)
    }

    @Test @MainActor func serverFailuresAndTimeoutsAreNotNetworkRecoveryCandidates() async {
        for error in [UsageConnectorError.serverError("HTTP 503"), .timedOut, .malformedResponse] {
            let connector = RecoveryConnector(failures: [error])
            let store = makeStore(connector)
            await store.refresh(force: false, allowInteraction: false)
            await store.recoverAfterNetworkChange()
            #expect(await connector.calls == 1)
        }
    }

    @Test @MainActor func bothAutomaticAndManualRecoveryRespectRetryAfter() async {
        let clock = RecoveryClock()
        let connector = RecoveryConnector(failures: [.rateLimited(retryAfter: 3600)])
        let store = makeStore(connector, clock: clock)
        await store.refresh(force: false, allowInteraction: false)
        for _ in 0..<4 {
            await store.recoverAfterNetworkChange()
            await store.refreshManually()
        }
        #expect(await connector.calls == 1)
        clock.advance(3601)
        await store.refreshManually()
        #expect(await connector.calls == 2)
    }

    @Test @MainActor func throttlingWithoutRetryAfterStillHasAProtectedWait() async {
        let connector = RecoveryConnector(failures: [.rateLimited(retryAfter: nil)])
        let store = makeStore(connector)
        await store.refresh(force: false, allowInteraction: false)
        await store.refreshManually()
        #expect(await connector.calls == 1)
    }

    @Test @MainActor func recoveryDoesNotPollHealthyOrThrottledPeersEarly() async {
        for peerFailures in [[], [UsageConnectorError.rateLimited(retryAfter: 3600)]] {
            let codex = RecoveryConnector(failures: [.networkUnavailable])
            let claude = RecoveryConnector(.claude, failures: peerFailures)
            let store = makeStore(codex, claude: claude)
            await store.refresh(force: false, allowInteraction: false)
            await store.recoverAfterNetworkChange()
            #expect(await codex.calls == 2)
            #expect(await claude.calls == 1)
        }
    }

    @Test @MainActor func signInRequiredIsNeverRetriedByTheNewActions() async {
        for error in [UsageConnectorError.notAuthenticated("sign in"), .reauthenticationRequired("reconnect")] {
            let connector = RecoveryConnector(failures: [error])
            let store = makeStore(connector)
            await store.refresh(force: false, allowInteraction: false)
            await store.recoverAfterNetworkChange()
            await store.refreshManually()
            #expect(await connector.calls == 1)
            #expect(store.connectionStatuses.first { $0.id == .codex }?.dataState == .reauthRequired)
        }
    }

    @Test @MainActor func manualRefreshOverridesOnlyTheLocalTimerAndCoalescesClicks() async {
        let clock = RecoveryClock()
        let connector = RecoveryConnector()
        let store = makeStore(connector, clock: clock)
        await store.refreshManually()
        for _ in 0..<5 { await store.refreshManually() }
        #expect(await connector.calls == 1)
        clock.advance(6)
        await store.refresh(force: false, allowInteraction: false)
        #expect(await connector.calls == 1)
        await store.refreshManually()
        #expect(await connector.calls == 2)
        #expect(await connector.interactions == [false, false])
    }

    @Test @MainActor func flappingNetworkIsLimitedToOneRecoveryPerThirtySeconds() async {
        let clock = RecoveryClock()
        let connector = RecoveryConnector(failures: [.networkUnavailable, .networkUnavailable])
        let store = makeStore(connector, clock: clock)
        await store.refresh(force: false, allowInteraction: false)
        for _ in 0..<8 { await store.recoverAfterNetworkChange() }
        #expect(await connector.calls == 2)
        clock.advance(31)
        await store.recoverAfterNetworkChange()
        #expect(await connector.calls == 3)
    }

    @Test @MainActor func disablingAutomaticUpdatesStillAllowsAnExplicitManualRefresh() async {
        let connector = RecoveryConnector(failures: [.networkUnavailable])
        let store = makeStore(connector)
        await store.refresh(force: false, allowInteraction: false)
        store.setAutomaticPollingEnabled(false)
        await store.recoverAfterNetworkChange()
        #expect(await connector.calls == 1)
        await store.refreshManually()
        #expect(await connector.calls == 2)
    }

    @Test @MainActor func networkNotificationsWaitForInFlightFetchWithoutDuplicatingIt() async {
        let connector = RecoveryConnector(failures: [.networkUnavailable], holdFirst: true)
        let store = makeStore(connector)
        let first = Task { await store.refresh(force: false, allowInteraction: false) }
        while !(await connector.started()) { await Task.yield() }
        await store.refreshManually()
        let recoveryA = Task { await store.recoverAfterNetworkChange() }
        let recoveryB = Task { await store.recoverAfterNetworkChange() }
        await connector.release()
        await first.value
        await recoveryA.value
        await recoveryB.value
        #expect(await connector.calls == 2)
        #expect(!store.isRefreshing)
    }

    @Test @MainActor func cancelledRecoveryDoesNotQueueAnExtraFetch() async {
        let connector = RecoveryConnector(failures: [.networkUnavailable], holdFirst: true)
        let store = makeStore(connector)
        let first = Task { await store.refresh(force: false, allowInteraction: false) }
        while !(await connector.started()) { await Task.yield() }
        let recovery = Task { await store.recoverAfterNetworkChange() }
        recovery.cancel()
        await connector.release()
        await first.value
        await recovery.value
        #expect(await connector.calls == 1)
    }

    @Test @MainActor func offlineFailuresDoNotOpenTheServerCircuitBreaker() async {
        let direct = RecoveryConnector(failures: [.networkUnavailable, .networkUnavailable, .networkUnavailable])
        let connector = ResilientUsageConnector(direct: direct, localFallback: nil)
        let store = makeStore(connector)
        for _ in 0..<4 { await store.refresh(force: true, allowInteraction: false) }
        #expect(await direct.calls == 4)
        #expect(store.snapshots.first { $0.id == .codex }?.source == .live)
    }

    @Test @MainActor func serverCircuitBreakerIsNotResetByNetworkOrManualRecovery() async {
        let direct = RecoveryConnector(failures: [.serverError("503"), .serverError("503"), .serverError("503")])
        let connector = ResilientUsageConnector(direct: direct, localFallback: nil)
        let store = makeStore(connector)
        for _ in 0..<3 { await store.refresh(force: true, allowInteraction: false) }
        await store.recoverAfterNetworkChange()
        await store.refreshManually()
        #expect(await direct.calls == 3)
    }

    @Test func onlyExplicitNetworkErrorsGetTheRecoveryClassification() async {
        for (input, expected) in [(DirectUsageError.networkUnavailable, UsageConnectorError.networkUnavailable),
                                  (.transport, .serverError(DirectUsageError.transport.localizedDescription)),
                                  (.timedOut, .timedOut), (.rateLimited(retryAfter: 60), .rateLimited(retryAfter: 60))] {
            do {
                _ = try await DirectUsageConnector(adapter: RecoveryAdapter(error: input)).fetchSnapshot()
                Issue.record("Expected failure")
            } catch let actual as UsageConnectorError { #expect(actual == expected) }
            catch { Issue.record("Unexpected error type") }
        }
    }

    @MainActor private func makeStore(
        _ codex: any UsageConnector,
        claude: (any UsageConnector)? = nil,
        clock: RecoveryClock = RecoveryClock()
    ) -> UsageStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = UsageSnapshotCache(fileURL: root.appendingPathComponent("usage.json"))
        try? cache.save([ProviderUsageSnapshot(id: .codex,
            session: UsageWindow(usedPercent: nil, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 37, resetsAt: nil),
            observedAt: .now, source: .live, message: nil)])
        return UsageStore(codexConnector: codex, claudeConnector: claude, cache: cache,
                          historyCache: UsageHistoryCache(fileURL: root.appendingPathComponent("history.json")),
                          clock: { clock.now() })
    }
}
