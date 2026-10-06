import AIUsageCore
import Foundation
import Testing
@testable import AIUsageProviderServices

private actor RefreshStub: DirectUsageAdapter {
    nonisolated let providerID: UsageProviderID
    let snapshot: ProviderUsageSnapshot
    var calls = 0
    var error: DirectUsageError?
    var held: CheckedContinuation<Void, Never>?
    var pause = false
    init(_ provider: UsageProviderID, now: Date) {
        providerID = provider
        snapshot = ProviderUsageSnapshot(id: provider,
            session: UsageWindow(usedPercent: 25, resetsAt: now.addingTimeInterval(7200)),
            weekly: UsageWindow(usedPercent: 40, resetsAt: nil), observedAt: now,
            source: .live, message: "PRIVATE")
    }
    func setError(_ error: DirectUsageError?) { self.error = error }
    func setPaused() { pause = true }
    func disablePause() { pause = false }
    func resume() { held?.resume(); held = nil }
    func fetchSnapshot() async throws -> ProviderUsageSnapshot {
        calls += 1
        if pause { await withCheckedContinuation { held = $0 } }
        if let error { throw error }
        return snapshot
    }
}

private struct RefreshFixture {
    let directory: URL
    let cache: LastKnownCache
    let history: UsageHistoryCache
    let claude: RefreshStub
    let codex: RefreshStub
    let now = Date.now
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("RefreshTests-\(UUID().uuidString)")
        cache = LastKnownCache(fileURL: directory.appendingPathComponent("usage-cache.json"))
        history = UsageHistoryCache(fileURL: directory.appendingPathComponent("usage-history.json"))
        claude = RefreshStub(.claude, now: now)
        codex = RefreshStub(.codex, now: now)
    }
    func service() -> SharedUsageRefresh {
        SharedUsageRefresh(claude: claude, codex: codex, cache: cache, historyCache: history)
    }
    func cleanup() { try? FileManager.default.removeItem(at: directory) }
}

struct SharedUsageRefreshTests {
    @Test func cancellationIsNotReportedAsProviderFailure() async throws {
        let f = try RefreshFixture(); defer { f.cleanup() }
        await f.claude.setPaused()
        let service = f.service()
        let task = Task { try await service.refresh(context: "background", at: f.now) }
        while await f.claude.held == nil { await Task.yield() }
        task.cancel()
        await f.claude.resume()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(service.evidenceCache.load()[.claude]?.failedAt == nil)
            #expect(f.cache.load().isEmpty)
        }
        await f.claude.disablePause()
        let next = try await service.refresh(context: "foreground", force: true, at: f.now)
        #expect(next.didRefresh)
    }
    @Test func backgroundFetchPersistsNewValuesAndEvidence() async throws {
        let f = try RefreshFixture(); defer { f.cleanup() }
        let service = f.service()
        let result = try await service.refresh(context: "widget", at: f.now)
        #expect(result.didRefresh)
        #expect(f.cache.load()[.claude]?.session.usedPercent == 25)
        #expect(result.states[.codex] == .live)
        #expect(service.evidenceCache.load()[.claude]?.context == "widget")
        #expect(service.evidenceCache.load()[.claude]?.failedAt == nil)
        let data = try String(contentsOf: service.evidenceCache.fileURL, encoding: .utf8)
        #expect(!data.contains("PRIVATE"))
    }

    @Test func timelineReloadWithinCadenceDoesNotQueryAgain() async throws {
        let f = try RefreshFixture(); defer { f.cleanup() }
        _ = try await f.service().refresh(context: "widget", at: f.now)
        let next = try await f.service().refresh(context: "background", at: f.now.addingTimeInterval(120))
        #expect(!next.didRefresh)
        #expect(await f.claude.calls == 1)
        #expect(await f.codex.calls == 1)
    }

    @Test func failedFetchKeepsValueAndRecoveryClearsFailure() async throws {
        let f = try RefreshFixture(); defer { f.cleanup() }
        let service = f.service()
        _ = try await service.refresh(context: "foreground", at: f.now)
        await f.claude.setError(.transport)
        let failed = try await service.refresh(context: "widget", at: f.now.addingTimeInterval(301))
        #expect(failed.snapshots.first { $0.id == .claude }?.session.usedPercent == 25)
        #expect(failed.states[.claude] == .stale)
        #expect(service.evidenceCache.load()[.claude]?.failed(after: f.now) == true)
        await f.claude.setError(nil)
        _ = try await service.refresh(context: "foreground", force: true, at: f.now.addingTimeInterval(302))
        #expect(service.evidenceCache.load()[.claude]?.failed(after: f.now) == false)
    }

    @Test func separateCoordinatorsCannotRotateTokensConcurrently() async throws {
        let f = try RefreshFixture(); defer { f.cleanup() }
        await f.claude.setPaused()
        let first = Task { try await f.service().refresh(context: "widget", at: f.now) }
        while await f.claude.held == nil { await Task.yield() }
        let second = try await f.service().refresh(context: "background", force: true, at: f.now)
        #expect(!second.didRefresh)
        #expect(await f.claude.calls == 1)
        await f.claude.resume()
        _ = try await first.value
    }

    @Test func rateLimitBackoffSurvivesCoordinatorRestart() async throws {
        let f = try RefreshFixture(); defer { f.cleanup() }
        await f.claude.setError(.rateLimited(retryAfter: 600))
        _ = try await f.service().refresh(context: "widget", at: f.now)
        _ = try await f.service().refresh(context: "foreground", force: true, at: f.now.addingTimeInterval(20))
        #expect(await f.claude.calls == 1)
        #expect(f.service().evidenceCache.load()[.claude]?.errorCode == "rate_limited")
    }

    @Test func oldDataWithoutFailedAttemptIsNotFailure() {
        let now = Date.now
        let old = now.addingTimeInterval(-3600)
        let saved = UsageRefreshEvidence(attemptedAt: old, succeededAt: old, context: "foreground")
        #expect(!saved.failed(after: old))
        let recovered = UsageRefreshEvidence(attemptedAt: now, succeededAt: now,
            failedAt: old, context: "foreground")
        #expect(!recovered.failed(after: old))
        let failed = UsageRefreshEvidence(attemptedAt: now, succeededAt: old,
            failedAt: now, context: "widget")
        #expect(failed.failed(after: old))
        let snapshot = ProviderUsageSnapshot(id: .claude,
            session: UsageWindow(usedPercent: 25, resetsAt: nil),
            weekly: UsageWindow(usedPercent: nil, resetsAt: nil),
            observedAt: old, source: .live, message: nil)
        #expect(snapshot.refreshDisposition(evidence: nil, at: now) == .saved)
        #expect(snapshot.refreshDisposition(evidence: saved, at: now) == .saved)
        #expect(snapshot.refreshDisposition(evidence: failed, at: now) == .failed)
        #expect(snapshot.refreshDisposition(evidence: saved, at: old) == .current)
    }
}
