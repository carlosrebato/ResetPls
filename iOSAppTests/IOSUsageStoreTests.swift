import AIUsageCore
import AIUsageProviderServices
import AIUsageDesignSystem
import SwiftUI
import XCTest
@testable import AIUsageIOS

@MainActor
final class IOSUsageStoreTests: XCTestCase {
    func testDemoDoesNotFetchOrOverwriteRealCacheAndRestoresAccounts() async throws {
        let fixture = try Fixture()
        let real = Self.snapshot(provider: .claude, percent: 19, source: .live)
        try fixture.cache.save([real])
        try fixture.statusCache.save([.claude: .live, .codex: .setupRequired])
        _ = try fixture.historyCache.recording([real], at: real.observedAt)
        let savedHistory = fixture.historyCache.load()
        let claude = StubAdapter(provider: .claude, result: .success(real))
        let codex = StubAdapter(provider: .codex, result: .failure(DirectUsageError.notAuthenticated))
        let store = IOSUsageStore(claude: claude, codex: codex,
            cache: fixture.cache, historyCache: fixture.historyCache, statusCache: fixture.statusCache)
        store.setDemoMode(true)
        XCTAssertTrue(store.isDemoMode)
        XCTAssertEqual(store.snapshots.count, 2)
        XCTAssertTrue(store.snapshots.allSatisfy { $0.source == .mock })
        await store.refresh(force: true)
        await store.refreshIfDue(at: .now)
        await store.signIn(.claude) { XCTFail("Demo must not authenticate") }
        await store.signOut(.claude)
        let claudeCalls = await claude.fetchCount()
        let codexCalls = await codex.fetchCount()
        XCTAssertEqual(claudeCalls, 0)
        XCTAssertEqual(codexCalls, 0)
        XCTAssertEqual(fixture.cache.load()[.claude], real)
        XCTAssertEqual(fixture.historyCache.load(), savedHistory)
        XCTAssertEqual(fixture.statusCache.load()[.claude]?.state, .live)
        store.setDemoMode(false)
        XCTAssertFalse(store.isDemoMode)
        XCTAssertEqual(store.snapshots.first?.session.usedPercent, 19)
        XCTAssertEqual(store.snapshots.first?.source, .cached)
        XCTAssertEqual(store.states[.claude], .live)
        XCTAssertEqual(store.history, savedHistory)
        await store.refresh()
        let callsAfterExit = await claude.fetchCount()
        XCTAssertEqual(callsAfterExit, 1)
    }

    func testDemoExitWithoutAccountsRestoresEmptyState() throws {
        let fixture = try Fixture()
        let store = IOSUsageStore(cache: fixture.cache, historyCache: fixture.historyCache,
                                  statusCache: fixture.statusCache)
        store.setDemoMode(true)
        store.setDemoMode(false)
        XCTAssertTrue(store.snapshots.isEmpty)
        XCTAssertEqual(store.states[.claude], .setupRequired)
        XCTAssertEqual(store.states[.codex], .setupRequired)
        XCTAssertEqual(store.history, fixture.historyCache.load())
    }

    func testDemoCannotReplaceAnInFlightSignIn() async throws {
        let fixture = try Fixture()
        let store = IOSUsageStore(cache: fixture.cache, historyCache: fixture.historyCache,
                                  statusCache: fixture.statusCache)
        await store.signIn(.claude) {
            store.setDemoMode(true)
            XCTAssertFalse(store.isDemoMode)
            throw CancellationError()
        }
        XCTAssertFalse(store.isDemoMode)
        XCTAssertTrue(store.authenticatingProviders.isEmpty)
    }

    func testPrivacyManifestIsEmbeddedInAppAndWidget() throws {
        let app = Bundle.main.bundleURL
        let plugins = try FileManager.default.contentsOfDirectory(
            at: app.appendingPathComponent("PlugIns"), includingPropertiesForKeys: nil)
        let widget = try XCTUnwrap(plugins.first { $0.pathExtension == "appex" })
        for bundle in [app, widget] {
            let data = try Data(contentsOf: bundle.appendingPathComponent("PrivacyInfo.xcprivacy"))
            let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(
                from: data, format: nil) as? [String: Any])
            XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
            let apis = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
            let defaults = try XCTUnwrap(apis.first {
                $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
            })
            XCTAssertEqual(Set(defaults["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []),
                           ["CA92.1", "1C8F.1"])
        }
    }

    func testReturnReusesFreshBackgroundObservationAndManualRefreshStillWorks() async throws {
        let fixture = try Fixture()
        let now = Date.now
        func reading(_ provider: UsageProviderID) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(id: provider,
                session: UsageWindow(usedPercent: 25, resetsAt: now.addingTimeInterval(7200)),
                weekly: UsageWindow(usedPercent: 40, resetsAt: nil),
                observedAt: now, source: .live, message: nil)
        }
        let claude = StubAdapter(provider: .claude, result: .success(reading(.claude)))
        let codex = StubAdapter(provider: .codex, result: .success(reading(.codex)))
        let background = SharedUsageRefresh(claude: claude, codex: codex,
            cache: fixture.cache, historyCache: fixture.historyCache)
        _ = try await background.refresh(context: "background")
        let store = IOSUsageStore(claude: claude, codex: codex,
            cache: fixture.cache, historyCache: fixture.historyCache)
        await store.refresh()
        let automaticCalls = await claude.fetchCount()
        XCTAssertEqual(automaticCalls, 1)
        XCTAssertEqual(store.states[.claude], .live)
        XCTAssertEqual(store.snapshots.first { $0.id == .claude }?.source, .live)
        let days = store.history.lastSevenDays(relativeTo: now)
        let trend = UsageTrend(days: days, providers: [.claude, .codex])
        XCTAssertEqual(trend.metric, .percent)
        XCTAssertEqual(trend.value(for: try XCTUnwrap(days.last), provider: .claude), 40)
        XCTAssertEqual(trend.value(for: try XCTUnwrap(days.last), provider: .codex), 40)
        await store.refresh(force: true)
        let manualCalls = await claude.fetchCount()
        XCTAssertEqual(manualCalls, 2)
    }
    func testDiagnosticExportsResetWithoutPrivateMessages() throws {
        let fixture = try Fixture()
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let reset = now.addingTimeInterval(18_000)
        let snapshot = ProviderUsageSnapshot(id: .claude,
            session: UsageWindow(usedPercent: 25, resetsAt: reset, durationSeconds: 18_000),
            weekly: UsageWindow(usedPercent: 40, resetsAt: nil, durationSeconds: 604_800),
            observedAt: now, source: .live, message: "PRIVATE-MESSAGE-DO-NOT-EXPORT")
        try fixture.cache.save([snapshot])
        let store = IOSUsageStore(
            claude: StubAdapter(provider: .claude, result: .success(snapshot)),
            codex: StubAdapter(provider: .codex, result: .failure(DirectUsageError.notAuthenticated)),
            cache: fixture.cache, historyCache: fixture.historyCache)
        let report = store.diagnosticReport(at: now)
        XCTAssertFalse(report.contains("PRIVATE-MESSAGE"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(report.utf8)) as? [String: Any])
        let providers = try XCTUnwrap(json["providers"] as? [[String: Any]])
        let claude = try XCTUnwrap(providers.first { $0["provider"] as? String == "claude" })
        let session = try XCTUnwrap(claude["session"] as? [String: Any])
        XCTAssertEqual(session["usedPercent"] as? Double, 25)
        XCTAssertNotNil(session["resetsAt"] as? String)
        XCTAssertEqual(claude["hasTokenTotals"] as? Bool, false)
        XCTAssertEqual(Set(claude.keys), ["provider", "state", "source", "observedAt", "session", "weekly", "hasTokenTotals"])
    }

    func testInlineProviderImagesHaveBoundedNaturalSize() throws {
        // The real inline host ignores frame/resizable modifiers. Ensure the
        // image attachments themselves fit a line, even before host layout.
        for provider in UsageProviderID.allCases {
            let rendered = try XCTUnwrap(ImageRenderer(content:
                Text("\(ProviderGlyph.inlineImage(provider: provider))")
                    .font(.system(size: 14))).uiImage)
            XCTAssertGreaterThan(rendered.size.width, 0)
            XCTAssertLessThanOrEqual(rendered.size.width, 18)
            XCTAssertLessThanOrEqual(rendered.size.height, 24)
        }
        let both = try XCTUnwrap(ImageRenderer(content:
            Text("\(ProviderGlyph.inlineImage(provider: .claude)) 4% · \(ProviderGlyph.inlineImage(provider: .codex)) 15%")
                .font(.system(size: 14))).uiImage)
        XCTAssertGreaterThan(both.size.width, 60)
        XCTAssertLessThan(both.size.width, 150)
        XCTAssertLessThanOrEqual(both.size.height, 24)
    }

    func testRestartPreservesSessionConclusionAtTheBoundary() async throws {
        let fixture = try Fixture()
        let now = Date.now
        let start = now.addingTimeInterval(-31 * 60)
        let reset = start.addingTimeInterval(18_000)
        func reading(_ percent: Double, minute: Double) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(id: .claude,
                session: UsageWindow(usedPercent: percent, resetsAt: reset, durationSeconds: 18_000),
                weekly: UsageWindow(usedPercent: nil, resetsAt: nil),
                observedAt: start.addingTimeInterval(minute * 60), source: .live, message: nil)
        }
        let safe = reading(2, minute: 20).recordingPace(previous: nil)
        let boundary = reading(10, minute: 30).recordingPace(previous: safe)
        try fixture.cache.save([boundary])
        let store = IOSUsageStore(
            claude: StubAdapter(provider: .claude, result: .success(reading(10, minute: 31))),
            codex: StubAdapter(provider: .codex, result: .failure(DirectUsageError.notAuthenticated)),
            cache: fixture.cache, historyCache: fixture.historyCache)
        XCTAssertEqual(store.snapshots.first?.sessionPaceStatus(at: now), .unavailable)
        await store.refresh(force: true)
        let current = try XCTUnwrap(store.snapshots.first { $0.id == .claude })
        XCTAssertEqual(current.sessionPaceStatus(at: now), .onTrack)
        XCTAssertEqual(current.sessionPaceAssessment(at: now)?.reason, .stabilized)
        XCTAssertEqual(fixture.cache.load()[.claude]?.paceHistory?.sessionConclusion?.atRisk, false)
    }

    func testWidgetFallsBackToCachedProviderWhenVisibilityWasNeverInitialized() {
        let suite = "ProviderVisibility.iOSWidgetFallback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(
            ProviderVisibilityPreferences.displayedProviders(
                cachedProviders: [.codex],
                in: defaults
            ),
            [.codex]
        )
    }

    func testExplicitWidgetVisibilityWinsOverCachedProviders() {
        let suite = "ProviderVisibility.iOSWidgetSelection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        ProviderVisibilityPreferences.setVisible(true, for: .claude, in: defaults)

        XCTAssertEqual(
            ProviderVisibilityPreferences.displayedProviders(
                cachedProviders: [.claude, .codex],
                in: defaults
            ),
            [.claude]
        )
    }

    func testRefreshContinuesCachedPaceHistoryAndPersistsIt() async throws {
        let fixture = try Fixture()
        let now = Date.now
        let reset = now.addingTimeInterval(7_200)
        func reading(_ percent: Double, seconds: Double) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(
                id: .codex, session: UsageWindow(usedPercent: percent, resetsAt: reset),
                weekly: UsageWindow(usedPercent: nil, resetsAt: nil),
                observedAt: now.addingTimeInterval(seconds), source: .live, message: nil
            )
        }
        let first = reading(55, seconds: -600).recordingPace(previous: nil)
        let second = reading(60, seconds: -300).recordingPace(previous: first)
        try fixture.cache.save([second])
        let store = IOSUsageStore(
            claude: StubAdapter(provider: .claude, result: .failure(DirectUsageError.notAuthenticated)),
            codex: StubAdapter(provider: .codex, result: .success(reading(65, seconds: 0))),
            cache: fixture.cache, historyCache: fixture.historyCache
        )
        XCTAssertNil(store.snapshots.first?.paceEstimate(at: now))
        await store.refresh(force: true)
        XCTAssertEqual(store.snapshots.first?.paceEstimate(at: now), .limitIn(2_100, quota: .session))
        XCTAssertEqual(fixture.cache.load()[.codex]?.paceHistory?.session.count, 3)
    }

    func testRestoresLastKnownSnapshotAsCached() throws {
        let fixture = try Fixture()
        let cached = Self.snapshot(provider: .claude, percent: 42, source: .live)
        try fixture.cache.save([cached])

        let store = IOSUsageStore(
            claude: StubAdapter(provider: .claude, result: .failure(DirectUsageError.transport)),
            codex: StubAdapter(provider: .codex, result: .failure(DirectUsageError.notAuthenticated)),
            cache: fixture.cache,
            historyCache: fixture.historyCache
        )

        XCTAssertEqual(store.snapshots.first?.source, .cached)
        XCTAssertEqual(store.snapshots.first?.session.usedPercent, 42)
        XCTAssertEqual(store.states[.claude], .cached)
        XCTAssertEqual(store.states[.codex], .setupRequired)
    }

    func testSuccessfulRefreshPersistsSnapshot() async throws {
        let fixture = try Fixture()
        let live = Self.snapshot(provider: .codex, percent: 67, source: .live)
        let store = IOSUsageStore(
            claude: StubAdapter(provider: .claude, result: .failure(DirectUsageError.notAuthenticated)),
            codex: StubAdapter(provider: .codex, result: .success(live)),
            cache: fixture.cache,
            historyCache: fixture.historyCache
        )

        await store.refresh(force: true)

        XCTAssertEqual(store.states[.codex], .live)
        XCTAssertEqual(fixture.cache.load()[.codex]?.session.usedPercent, 67)
        XCTAssertEqual(store.history.days.last?.codexPercent, 67)
    }

    func testFailedRefreshKeepsCachedSnapshotVisible() async throws {
        let fixture = try Fixture()
        try fixture.cache.save([Self.snapshot(provider: .claude, percent: 31, source: .live)])
        let store = IOSUsageStore(
            claude: StubAdapter(provider: .claude, result: .failure(DirectUsageError.transport)),
            codex: StubAdapter(provider: .codex, result: .failure(DirectUsageError.notAuthenticated)),
            cache: fixture.cache,
            historyCache: fixture.historyCache
        )

        await store.refresh(force: true)

        XCTAssertEqual(store.states[.claude], .stale)
        XCTAssertEqual(store.snapshots.first { $0.id == .claude }?.session.usedPercent, 31)
        XCTAssertEqual(store.snapshots.first { $0.id == .claude }?.source, .cached)
        XCTAssertNil(store.snapshots.first { $0.id == .claude }?.paceEstimate(at: .now))
        XCTAssertEqual(store.states[.codex], .setupRequired)
    }

    func testExpiredSessionKeepsLastValueAndOnlyMarksAffectedProviderForReauth() async throws {
        let fixture = try Fixture()
        try fixture.cache.save([
            Self.snapshot(provider: .claude, percent: 31, source: .live),
            Self.snapshot(provider: .codex, percent: 64, source: .live)
        ])
        let store = IOSUsageStore(
            claude: StubAdapter(
                provider: .claude,
                result: .failure(DirectUsageError.rejected(status: 401))
            ),
            codex: StubAdapter(
                provider: .codex,
                result: .success(Self.snapshot(provider: .codex, percent: 66, source: .live))
            ),
            cache: fixture.cache,
            historyCache: fixture.historyCache
        )

        await store.refresh(force: true)

        XCTAssertEqual(store.states[.claude], .reauthRequired)
        XCTAssertEqual(store.states[.codex], .live)
        XCTAssertEqual(store.snapshots.first { $0.id == .claude }?.session.usedPercent, 31)
        XCTAssertEqual(store.snapshots.first { $0.id == .claude }?.source, .cached)
        XCTAssertEqual(fixture.statusCache.load()[.claude]?.state, .reauthRequired)
        XCTAssertEqual(fixture.statusCache.load()[.codex]?.state, .live)
    }

    func testCancelledReauthenticationRestoresCachedValueAndState() async throws {
        let fixture = try Fixture()
        try fixture.cache.save([Self.snapshot(provider: .codex, percent: 64, source: .live)])
        let store = IOSUsageStore(
            claude: StubAdapter(provider: .claude, result: .failure(DirectUsageError.transport)),
            codex: StubAdapter(provider: .codex, result: .failure(DirectUsageError.rejected(status: 401))),
            cache: fixture.cache,
            historyCache: fixture.historyCache
        )
        await store.refresh(force: true)

        await store.signIn(.codex) { throw CancellationError() }

        XCTAssertEqual(store.states[.codex], .reauthRequired)
        XCTAssertEqual(store.snapshots.first { $0.id == .codex }?.weekly.usedPercent, 69)
        XCTAssertEqual(fixture.cache.load()[.codex]?.weekly.usedPercent, 69)
    }

    private static func snapshot(
        provider: UsageProviderID,
        percent: Double,
        source: UsageSource
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            id: provider,
            session: UsageWindow(usedPercent: percent, resetsAt: nil),
            weekly: UsageWindow(usedPercent: percent + 5, resetsAt: nil),
            observedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: source,
            message: "Test"
        )
    }
}

private actor StubAdapter: DirectUsageAdapter {
    nonisolated let providerID: UsageProviderID
    private let result: Result<ProviderUsageSnapshot, Error>
    private var calls = 0

    init(provider: UsageProviderID, result: Result<ProviderUsageSnapshot, Error>) {
        providerID = provider
        self.result = result
    }

    func fetchSnapshot() async throws -> ProviderUsageSnapshot {
        calls += 1
        return try result.get()
    }
    func fetchCount() -> Int { calls }
}

private final class Fixture {
    let directory: URL
    let cache: LastKnownCache
    let historyCache: UsageHistoryCache
    let statusCache: ProviderStatusCache

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIUsageIOSTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cache = LastKnownCache(fileURL: directory.appendingPathComponent("usage-cache.json"))
        historyCache = UsageHistoryCache(fileURL: directory.appendingPathComponent("usage-history.json"))
        statusCache = ProviderStatusCache(fileURL: directory.appendingPathComponent("provider-status.json"))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}
