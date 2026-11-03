import Foundation
import CoreFoundation

public struct UsageHistoryDay: Identifiable, Equatable, Codable, Sendable {
    public let date: Date
    public var claudePercent: Double?
    public var codexPercent: Double?
    public var claudeTokens: Int?
    public var codexTokens: Int?
    public var activity: Bool?
    // Separate fields: legacy percentages were daily peaks of the primary
    // window (Claude session, Codex week), not comparable weekly balances.
    public var claudeWeeklyPercent: Double?
    public var codexWeeklyPercent: Double?
    public var claudeWeeklyObservedAt: Date?
    public var codexWeeklyObservedAt: Date?

    public init(
        date: Date,
        claudePercent: Double? = nil,
        codexPercent: Double? = nil,
        claudeTokens: Int? = nil,
        codexTokens: Int? = nil,
        activity: Bool? = nil,
        claudeWeeklyPercent: Double? = nil,
        codexWeeklyPercent: Double? = nil,
        claudeWeeklyObservedAt: Date? = nil,
        codexWeeklyObservedAt: Date? = nil
    ) {
        self.date = date
        self.claudePercent = claudePercent
        self.codexPercent = codexPercent
        self.claudeTokens = claudeTokens
        self.codexTokens = codexTokens
        self.activity = activity
        self.claudeWeeklyPercent = claudeWeeklyPercent
        self.codexWeeklyPercent = codexWeeklyPercent
        self.claudeWeeklyObservedAt = claudeWeeklyObservedAt
        self.codexWeeklyObservedAt = codexWeeklyObservedAt
    }

    public var id: Date { date }

    public var hasUsage: Bool {
        activity == true
            || (claudeTokens ?? 0) > 0
            || (codexTokens ?? 0) > 0
    }

    public func percent(for provider: UsageProviderID) -> Double? {
        switch provider {
        case .claude: claudePercent
        case .codex: codexPercent
        }
    }

    public func tokens(for provider: UsageProviderID) -> Int? {
        switch provider {
        case .claude: claudeTokens
        case .codex: codexTokens
        }
    }

    public func weeklyPercent(for provider: UsageProviderID) -> Double? {
        switch provider {
        case .claude: claudeWeeklyPercent
        case .codex: codexWeeklyPercent
        }
    }
}

public struct UsageHistory: Equatable, Codable, Sendable {
    public var days: [UsageHistoryDay]

    public init(days: [UsageHistoryDay] = []) {
        self.days = days
    }

    public func lastSevenDays(relativeTo now: Date, calendar: Calendar = .current) -> [UsageHistoryDay] {
        let today = calendar.startOfDay(for: now)
        let indexed = Dictionary(uniqueKeysWithValues: days.map { (calendar.startOfDay(for: $0.date), $0) })
        return (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return indexed[date] ?? UsageHistoryDay(date: date)
        }
    }

    /// Keeps prior history intact while preventing a disconnected provider's
    /// saved/local value from looking like a live measurement for today.
    public func lastSevenDays(
        relativeTo now: Date,
        currentDayProviders: Set<UsageProviderID>,
        calendar: Calendar = .current
    ) -> [UsageHistoryDay] {
        var result = lastSevenDays(relativeTo: now, calendar: calendar)
        guard !result.isEmpty else { return result }
        let today = result.index(before: result.endIndex)
        if !currentDayProviders.contains(.claude) {
            result[today].claudePercent = nil
            result[today].claudeTokens = nil
            result[today].claudeWeeklyPercent = nil
        }
        if !currentDayProviders.contains(.codex) {
            result[today].codexPercent = nil
            result[today].codexTokens = nil
            result[today].codexWeeklyPercent = nil
        }
        return result
    }

    public func currentStreak(relativeTo now: Date, calendar: Calendar = .current) -> Int {
        let indexed = Dictionary(uniqueKeysWithValues: days.map {
            (calendar.startOfDay(for: $0.date), $0.hasUsage)
        })
        var date = calendar.startOfDay(for: now)
        var count = 0
        while indexed[date] == true {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return count
    }
}

public struct UsageHistoryCache: Sendable {
    public let fileURL: URL
    private static let writeLock = NSLock()

    /// Local recovery copies only; never uploaded. The baseline is never rotated.
    public var backupDirectoryURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent(
            fileURL.deletingPathExtension().lastPathComponent + "-backups", isDirectory: true
        )
    }

    public enum PersistenceError: Error {
        case unsupportedFormat
        case missingHistoryWithBackups
    }

    private struct Document {
        let history: UsageHistory
        let data: Data?
    }

    private func readForWriting() throws -> Document {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch CocoaError.fileReadNoSuchFile {
            // A missing primary file must not silently start over if recovery data exists.
            if FileManager.default.fileExists(atPath: backupDirectoryURL.path) {
                throw PersistenceError.missingHistoryWithBackups
            }
            return Document(history: UsageHistory(), data: nil)
        }
        let history = try JSONDecoder().decode(UsageHistory.self, from: data)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["days", "schemaVersion"]),
              let days = object["days"] as? [[String: Any]],
              Set(history.days.map(\.date)).count == history.days.count else {
            throw PersistenceError.unsupportedFormat
        }
        if let version = object["schemaVersion"] {
            guard let number = version as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(), number == 1 else {
                throw PersistenceError.unsupportedFormat
            }
        }
        let knownFields: Set<String> = [
            "date", "claudePercent", "codexPercent", "claudeTokens", "codexTokens", "activity",
            "claudeWeeklyPercent", "codexWeeklyPercent", "claudeWeeklyObservedAt", "codexWeeklyObservedAt"
        ]
        guard days.allSatisfy({ Set($0.keys).isSubset(of: knownFields) }) else {
            // Refuse to re-encode fields we cannot preserve, including future quota metrics.
            throw PersistenceError.unsupportedFormat
        }
        return Document(history: history, data: data)
    }

    private func save(_ history: UsageHistory, replacing document: Document) throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(history)) as! [String: Any]
        object["schemaVersion"] = 1
        let encoded = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let manager = FileManager.default
        try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Back up only validated, nonempty input, before touching the primary file.
        // Failure to create a required backup aborts the write too.
        if let original = document.data, !document.history.days.isEmpty {
            try manager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
            let baseline = backupDirectoryURL.appendingPathComponent("before-protection-v1.json")
            if !manager.fileExists(atPath: baseline.path) {
                try original.write(to: baseline, options: .atomic)
            }
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            let daily = backupDirectoryURL.appendingPathComponent("daily-\(formatter.string(from: Date())).json")
            if !manager.fileExists(atPath: daily.path) {
                try original.write(to: daily, options: .atomic)
            }
        }
        try encoded.write(to: fileURL, options: .atomic)

        // Rotation is best effort, after a successful save. Never remove the baseline.
        if let files = try? manager.contentsOfDirectory(at: backupDirectoryURL, includingPropertiesForKeys: nil) {
            let daily = files.filter {
                $0.lastPathComponent.range(of: #"^daily-\d{4}-\d{2}-\d{2}\.json$"#, options: .regularExpression) != nil
            }.sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in daily.dropFirst(7) { try? manager.removeItem(at: old) }
        }
    }

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
            .appendingPathComponent("usage-history.json")
    }

    public func load() -> UsageHistory {
        guard
            let data = try? Data(contentsOf: fileURL),
            let history = try? JSONDecoder().decode(UsageHistory.self, from: data)
        else { return UsageHistory() }
        return history
    }

    public func recording(
        _ snapshots: [ProviderUsageSnapshot],
        at now: Date,
        calendar: Calendar = .current
    ) throws -> UsageHistory {
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        let document = try readForWriting()
        var history = document.history
        let day = calendar.startOfDay(for: now)
        for snapshot in snapshots where snapshot.source == .live {
            if let weekly = snapshot.weekly.usedPercent, weekly.isFinite {
                // Refresh may finish after its start clock (even after midnight).
                // Attribute quota to the measurement's date, not refresh start.
                let observedDay = calendar.startOfDay(for: snapshot.observedAt)
                var entry = history.days.first { calendar.isDate($0.date, inSameDayAs: observedDay) }
                    ?? UsageHistoryDay(date: observedDay)
                let value = min(max(weekly, 0), 100)
                // Last observation, not maximum: a reset must be allowed to
                // lower the balance, including a courtesy reset midweek.
                switch snapshot.id {
                case .claude:
                    if snapshot.observedAt >= (entry.claudeWeeklyObservedAt ?? .distantPast) {
                        entry.claudeWeeklyPercent = value
                        entry.claudeWeeklyObservedAt = snapshot.observedAt
                    }
                case .codex:
                    if snapshot.observedAt >= (entry.codexWeeklyObservedAt ?? .distantPast) {
                        entry.codexWeeklyPercent = value
                        entry.codexWeeklyObservedAt = snapshot.observedAt
                    }
                }
                history.days.removeAll { calendar.isDate($0.date, inSameDayAs: observedDay) }
                history.days.append(entry)
            }
        }
        var entry = history.days.first { calendar.isDate($0.date, inSameDayAs: day) }
            ?? UsageHistoryDay(date: day)
        for snapshot in snapshots where snapshot.source == .live {
            guard let value = snapshot.primaryDisplayWindow.usedPercent, value.isFinite else { continue }
            switch snapshot.id {
            case .claude:
                entry.claudePercent = max(entry.claudePercent ?? 0, min(max(value, 0), 100))
            case .codex:
                entry.codexPercent = max(entry.codexPercent ?? 0, min(max(value, 0), 100))
            }
        }

        history.days.removeAll { calendar.isDate($0.date, inSameDayAs: day) }
        history.days.append(entry)
        let cutoff = calendar.date(byAdding: .day, value: -60, to: day) ?? .distantPast
        history.days = history.days.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }

        try save(history, replacing: document)
        return history
    }

    public func applyingActivityDates(
        _ activityDates: Set<Date>,
        periodStart: Date,
        periodEnd: Date,
        calendar: Calendar = .current
    ) throws -> UsageHistory {
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        let document = try readForWriting()
        var history = document.history
        let normalizedDates = Set(activityDates.map { calendar.startOfDay(for: $0) })
            .filter { periodStart <= $0 && $0 < periodEnd }

        // Missing logs do not prove inactivity. Merge positive evidence without
        // turning a partial or unavailable scan into false activity measurements.
        for index in history.days.indices {
            let day = calendar.startOfDay(for: history.days[index].date)
            if periodStart <= day && day < periodEnd && normalizedDates.contains(day) {
                history.days[index].activity = true
            }
        }

        for day in normalizedDates where !history.days.contains(where: {
            calendar.isDate($0.date, inSameDayAs: day)
        }) {
            history.days.append(UsageHistoryDay(date: day, activity: true))
        }

        history.days.sort { $0.date < $1.date }
        try save(history, replacing: document)
        return history
    }

    public func applyingDailyTokens(
        _ totals: [UsageProviderID: [Date: Int]],
        periodStart: Date,
        periodEnd: Date,
        calendar: Calendar = .current
    ) throws -> UsageHistory {
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        let document = try readForWriting()
        var history = document.history

        for provider in UsageProviderID.allCases {
            // A missing or empty scan is not proof that the user has no history.
            // Sandboxed access can be temporarily unavailable while a bookmark is
            // resolving, so preserve the last known series until real replacement
            // data is available.
            guard let providerTotals = totals[provider], !providerTotals.isEmpty else {
                continue
            }

            let normalized = Dictionary(
                providerTotals.map {
                    (calendar.startOfDay(for: $0.key), $0.value)
                },
                uniquingKeysWith: +
            )

            for (day, tokens) in normalized
            where periodStart <= day && day < periodEnd && tokens >= 0 {
                let index = history.days.firstIndex {
                    calendar.isDate($0.date, inSameDayAs: day)
                }
                if let index {
                    let existing = history.days[index].tokens(for: provider)
                    // Late reads may increase a closed day's total. Preserve the
                    // maximum on every day so partial scans cannot erase usage.
                    let stableValue = max(existing ?? 0, tokens)
                    switch provider {
                    case .claude: history.days[index].claudeTokens = stableValue
                    case .codex: history.days[index].codexTokens = stableValue
                    }
                } else {
                    var entry = UsageHistoryDay(date: day)
                    switch provider {
                    case .claude: entry.claudeTokens = tokens
                    case .codex: entry.codexTokens = tokens
                    }
                    history.days.append(entry)
                }
            }
        }

        history.days.sort { $0.date < $1.date }
        try save(history, replacing: document)
        return history
    }
}

/// One metric and one scale for all visible providers. Missing measurements stay
/// optional so the renderer can break a line instead of drawing a false zero.
public struct UsageTrend: Sendable {
    public enum Metric: String, Equatable, Sendable {
        case tokens
        case percent
    }

    public let days: [UsageHistoryDay]
    public let providers: Set<UsageProviderID>
    public let metric: Metric
    public let scaleMaximum: Double

    public init(days: [UsageHistoryDay], providers: Set<UsageProviderID>, metric: Metric = .percent) {
        self.days = days
        self.providers = providers
        let tokenValues = providers.flatMap { provider in
            days.compactMap { $0.tokens(for: provider) }
        }
        self.metric = metric
        scaleMaximum = metric == .percent ? 100 : Double(max(tokenValues.max() ?? 0, 1))
    }

    public func value(for day: UsageHistoryDay, provider: UsageProviderID) -> Double? {
        guard providers.contains(provider) else { return nil }
        // Zero-fill only the chart of a provider with evidence for this metric.
        // Do not fabricate cached measurements, activity, or a token series
        // for a provider whose history only contains quota percentages.
        return measuredValue(for: day, provider: provider)
            ?? (metric == .tokens && hasSeries(for: provider) ? 0 : nil)
    }

    private func measuredValue(for day: UsageHistoryDay, provider: UsageProviderID) -> Double? {
        switch metric {
        case .tokens:
            return day.tokens(for: provider).map { Double(max($0, 0)) }
        case .percent:
            guard let percent = day.weeklyPercent(for: provider), percent.isFinite else { return nil }
            return min(max(percent, 0), 100)
        }
    }

    public func normalizedValue(for day: UsageHistoryDay, provider: UsageProviderID) -> Double? {
        value(for: day, provider: provider).map { $0 / scaleMaximum }
    }

    public func hasSeries(for provider: UsageProviderID) -> Bool {
        providers.contains(provider)
            && days.contains { measuredValue(for: $0, provider: provider) != nil }
    }

    /// A known series continues through empty days at the chart's zero baseline.
    public func segments(for provider: UsageProviderID) -> [[Int]] {
        var result: [[Int]] = []
        var current: [Int] = []
        for index in days.indices {
            if value(for: days[index], provider: provider) != nil {
                current.append(index)
            } else if !current.isEmpty {
                result.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
