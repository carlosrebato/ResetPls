import Foundation

public struct UsageHistoryDay: Identifiable, Equatable, Codable, Sendable {
    public let date: Date
    public var claudePercent: Double?
    public var codexPercent: Double?
    public var claudeTokens: Int?
    public var codexTokens: Int?
    public var activity: Bool?

    public init(
        date: Date,
        claudePercent: Double? = nil,
        codexPercent: Double? = nil,
        claudeTokens: Int? = nil,
        codexTokens: Int? = nil,
        activity: Bool? = nil
    ) {
        self.date = date
        self.claudePercent = claudePercent
        self.codexPercent = codexPercent
        self.claudeTokens = claudeTokens
        self.codexTokens = codexTokens
        self.activity = activity
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
        }
        if !currentDayProviders.contains(.codex) {
            result[today].codexPercent = nil
            result[today].codexTokens = nil
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
        var history = load()
        let day = calendar.startOfDay(for: now)
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

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(history).write(to: fileURL, options: .atomic)
        return history
    }

    public func applyingActivityDates(
        _ activityDates: Set<Date>,
        periodStart: Date,
        periodEnd: Date,
        calendar: Calendar = .current
    ) throws -> UsageHistory {
        var history = load()
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
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(history).write(to: fileURL, options: .atomic)
        return history
    }

    public func applyingDailyTokens(
        _ totals: [UsageProviderID: [Date: Int]],
        periodStart: Date,
        periodEnd: Date,
        calendar: Calendar = .current
    ) throws -> UsageHistory {
        var history = load()

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
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(history).write(to: fileURL, options: .atomic)
        return history
    }
}

/// One metric and one scale for all visible providers. Missing measurements stay
/// optional so the renderer can break a line instead of drawing a false zero.
public struct UsageTrend: Sendable {
    public enum Metric: Equatable, Sendable {
        case tokens
        case percent
    }

    public let days: [UsageHistoryDay]
    public let providers: Set<UsageProviderID>
    public let metric: Metric
    public let scaleMaximum: Double

    public init(days: [UsageHistoryDay], providers: Set<UsageProviderID>) {
        self.days = days
        self.providers = providers
        let tokenValues = providers.flatMap { provider in
            days.compactMap { $0.tokens(for: provider) }
        }
        metric = tokenValues.isEmpty ? .percent : .tokens
        scaleMaximum = tokenValues.isEmpty ? 100 : Double(max(tokenValues.max() ?? 0, 1))
    }

    public func value(for day: UsageHistoryDay, provider: UsageProviderID) -> Double? {
        guard providers.contains(provider) else { return nil }
        // Zero-fill only the chart of a provider with evidence for this metric.
        // Do not fabricate cached measurements, activity, or a token series
        // for a provider whose history only contains quota percentages.
        return measuredValue(for: day, provider: provider)
            ?? (hasSeries(for: provider) ? 0 : nil)
    }

    private func measuredValue(for day: UsageHistoryDay, provider: UsageProviderID) -> Double? {
        switch metric {
        case .tokens:
            return day.tokens(for: provider).map { Double(max($0, 0)) }
        case .percent:
            guard let percent = day.percent(for: provider), percent.isFinite else { return nil }
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
