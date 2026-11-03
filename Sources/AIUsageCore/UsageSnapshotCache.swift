import Foundation

public enum AIUsageAppGroup {
    public static var identifier: String {
        if let override = ProcessInfo.processInfo.environment["AI_USAGE_APP_GROUP"],
           !override.isEmpty {
            return override
        }
        if let configured = Bundle.main.object(forInfoDictionaryKey: "AIUsageAppGroup") as? String,
           !configured.isEmpty {
            return configured
        }
        return "group.com.carlosrebato.aiusage"
    }
}

public enum AIUsageWidgetKind {
    public static let summary = "AIUsageWidget"
    public static let provider = "AIUsageProviderWidget"
}

public struct UsageSnapshotCache: Sendable {
    public let fileURL: URL

    public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let base = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: AIUsageAppGroup.identifier
        ) ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = base
            .appendingPathComponent("AIUsageMac", isDirectory: true)
            .appendingPathComponent("usage-cache.json")
    }

    public func load() -> [UsageProviderID: ProviderUsageSnapshot] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let snapshots = try? JSONDecoder().decode([ProviderUsageSnapshot].self, from: data)
        else { return [:] }

        return Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
    }

    public func save(_ snapshots: [ProviderUsageSnapshot]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Keep the last useful value even when a provider temporarily falls back
        // to cached data. Otherwise a successful refresh from another provider
        // can overwrite the cache and make this provider disappear on relaunch.
        let data = try JSONEncoder().encode(snapshots.filter { $0.highestPercent != nil })
        try data.write(to: fileURL, options: .atomic)
    }
}

/// Semantic wrapper used by provider orchestration: it stores only the last
/// useful numeric value and never replaces it with an unavailable response.
public struct LastKnownCache: Sendable {
    private let storage: UsageSnapshotCache

    public var fileURL: URL { storage.fileURL }

    public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        storage = UsageSnapshotCache(fileURL: fileURL, fileManager: fileManager)
    }

    public func load() -> [UsageProviderID: ProviderUsageSnapshot] {
        storage.load()
    }

    public func save(_ snapshots: [ProviderUsageSnapshot]) throws {
        try storage.save(snapshots)
    }
}

public struct ProviderStatusRecord: Codable, Equatable, Sendable {
    public let provider: UsageProviderID
    public let state: ProviderDataState
    public let recordedAt: Date

    public init(provider: UsageProviderID, state: ProviderDataState, recordedAt: Date) {
        self.provider = provider
        self.state = state
        self.recordedAt = recordedAt
    }
}

/// Shares non-sensitive connection state with widgets. Credentials and raw
/// provider errors never cross the app-group boundary.
public struct ProviderStatusCache: Sendable {
    public let fileURL: URL

    public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        if let fileURL {
            self.fileURL = fileURL
            return
        }
        let base = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: AIUsageAppGroup.identifier
        ) ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = base
            .appendingPathComponent("AIUsageMac", isDirectory: true)
            .appendingPathComponent("provider-status.json")
    }

    public func load() -> [UsageProviderID: ProviderStatusRecord] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let records = try? JSONDecoder().decode([ProviderStatusRecord].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.provider, $0) })
    }

    public func save(_ states: [UsageProviderID: ProviderDataState], at date: Date = .now) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let records = states.map { provider, state in
            ProviderStatusRecord(provider: provider, state: state, recordedAt: date)
        }
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: .atomic)
    }
}

/// iPhone demo selection is isolated from real readings, status and history.
public struct UsageDemoStore: Sendable {
    public let fileURL: URL
    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? UsageSnapshotCache().fileURL.deletingLastPathComponent()
            .appendingPathComponent("ios-widget-demo.flag")
    }
    public var isEnabled: Bool { FileManager.default.fileExists(atPath: fileURL.path) }
    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("demo".utf8).write(to: fileURL, options: .atomic)
        } else if isEnabled {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
    public static func snapshots(at now: Date) -> [ProviderUsageSnapshot] {
        return [
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
    }
    public static func history(at now: Date) -> UsageHistory {
        let calendar = Calendar.current
        let claude = [8.0, 17, 25, 32, 36, 40, 43]
        let codex = [25.0, 62, 0, 8, 17, 29, 37]
        let days = (-6...0).compactMap { offset -> UsageHistoryDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            let index = offset + 6
            return UsageHistoryDay(
                date: calendar.startOfDay(for: date),
                claudePercent: claude[index],
                codexPercent: codex[index],
                activity: true,
                claudeWeeklyPercent: claude[index],
                codexWeeklyPercent: codex[index]
            )
        }
        return UsageHistory(days: days)
    }
}
