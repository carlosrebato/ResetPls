import AIUsageCore
import AIUsageDesignSystem
import AppIntents
import SwiftUI
import WidgetKit

private struct UsageWidgetEntry: TimelineEntry {
    let date: Date
    let snapshots: [ProviderUsageSnapshot]
    let states: [UsageProviderID: ProviderDataState]
    let history: UsageHistory
}

enum WidgetProviderChoice: String, AppEnum {
    case automatic
    case claude
    case codex

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Service")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .automatic: "First connected service",
        .claude: "Claude Code",
        .codex: "Codex"
    ]

    var provider: UsageProviderID? {
        switch self {
        case .automatic: nil
        case .claude: .claude
        case .codex: .codex
        }
    }
}

struct ProviderWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose service"
    static let description = IntentDescription("Choose which service this widget displays.")

    // WidgetKit must see the default in extracted parameter metadata. An
    // optional dynamic parameter plus init() alone leaves first placement
    // dependent on the intent-resolution process, before timelines can run.
    @Parameter(title: "Service", default: .automatic)
    var provider: WidgetProviderChoice

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$provider)")
    }
}

private struct UsageWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageWidgetEntry {
        UsageWidgetEntry(date: .now, snapshots: Self.previewSnapshots,
                         states: [.claude: .live, .codex: .live], history: Self.previewHistory)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageWidgetEntry) -> Void) {
        completion(entry(usePreviewIfEmpty: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageWidgetEntry>) -> Void) {
        let entry = entry(usePreviewIfEmpty: false)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date)!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    fileprivate func entry(usePreviewIfEmpty: Bool) -> UsageWidgetEntry {
        if usePreviewIfEmpty {
            return UsageWidgetEntry(
                date: .now,
                snapshots: Self.previewSnapshots,
                states: [.claude: .live, .codex: .live],
                history: Self.previewHistory
            )
        }
        let cached = UsageSnapshotCache().load()
        let states = ProviderStatusCache().load().mapValues(\.state)
        // iOS builds prior to 0.1.3 (22) never initialized provider visibility.
        // Cached providers are therefore the safe source of truth when no explicit
        // selection exists; otherwise a connected account renders as “not connected”.
        let providers = ProviderVisibilityPreferences.displayedProviders(
            cachedProviders: Set(cached.keys)
        )
        let snapshots = providers.compactMap { cached[$0] }
        return UsageWidgetEntry(
            date: .now,
            snapshots: snapshots,
            states: states,
            history: UsageHistoryCache().load()
        )
    }

    private static let previewSnapshots = [
        ProviderUsageSnapshot(
            id: .claude,
            session: UsageWindow(usedPercent: 38, resetsAt: .now.addingTimeInterval(7_200)),
            weekly: UsageWindow(usedPercent: 54, resetsAt: .now.addingTimeInterval(259_200)),
            observedAt: .now, source: .mock, message: nil
        ),
        ProviderUsageSnapshot(
            id: .codex,
            session: UsageWindow(usedPercent: nil, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 47, resetsAt: .now.addingTimeInterval(345_600)),
            observedAt: .now, source: .mock, message: nil
        )
    ]

    private static let previewHistory = UsageHistory(days: (-6...0).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: offset, to: .now)!
        let index = offset + 6
        return UsageHistoryDay(
            date: date,
            claudePercent: [12, 46, 25, 52, 63, 68, 38][index],
            codexPercent: [8, 19, 18, 31, 28, 22, 47][index],
            activity: true
        )
    })
}

private struct ProviderWidgetTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsageWidgetEntry {
        configuredEntry(for: .claude, usePreviewIfEmpty: true)
    }

    func snapshot(for configuration: ProviderWidgetIntent, in context: Context) async -> UsageWidgetEntry {
        configuredEntry(for: resolvedProvider(configuration.provider), usePreviewIfEmpty: context.isPreview)
    }

    func timeline(for configuration: ProviderWidgetIntent, in context: Context) async -> Timeline<UsageWidgetEntry> {
        let entry = configuredEntry(for: resolvedProvider(configuration.provider), usePreviewIfEmpty: false)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date)!
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func configuredEntry(
        for provider: UsageProviderID,
        usePreviewIfEmpty: Bool
    ) -> UsageWidgetEntry {
        let base = UsageWidgetProvider().entry(usePreviewIfEmpty: usePreviewIfEmpty)
        return UsageWidgetEntry(
            date: base.date,
            snapshots: base.snapshots.filter { $0.id == provider },
            states: base.states,
            history: base.history
        )
    }

    private func resolvedProvider(_ choice: WidgetProviderChoice?) -> UsageProviderID {
        let cached = UsageSnapshotCache().load()
        let available = ProviderVisibilityPreferences.displayedProviders(
            cachedProviders: Set(cached.keys)
        )
        if let provider = choice?.provider { return provider }
        return ProviderOrderPreferences.ordered().first { available.contains($0) } ?? .claude
    }
}

private enum WidgetScope {
    case summary
    case provider(UsageProviderID)
}

private struct UsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageWidgetEntry
    let scope: WidgetScope
    private var language: AppLanguage { .current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: smallContent
            case .systemLarge: largeContent
            #if os(iOS)
            case .accessoryCircular: circularContent
            case .accessoryRectangular: rectangularContent
            case .accessoryInline: inlineContent
            #endif
            default: mediumContent
            }
        }
        .containerBackground(for: .widget) {
            #if os(iOS)
            if family == .accessoryInline || family == .accessoryCircular || family == .accessoryRectangular {
                Color.clear
            } else {
                UsageTheme.panelGradient
            }
            #else
            UsageTheme.panelGradient
            #endif
        }
    }

    @ViewBuilder
    private var smallContent: some View {
        if let snapshot = selectedSnapshot {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        ProviderGlyph(provider: snapshot.id, size: 13, color: UsageTheme.secondaryText)
                        Text(snapshot.id == .claude ? "CLAUDE" : "CODEX")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.05)
                            .foregroundStyle(UsageTheme.secondaryText)
                    }
                    Spacer(minLength: 4)
                    freshness(snapshot)
                }

                smallGauge(snapshot)
                    .padding(.top, 9)
                    .padding(.bottom, 11)

                Text(statusText(snapshot) ?? language.resetText(for: snapshot, now: entry.date))
                    .font(.system(size: 7.5, weight: .semibold))
                    .tracking(0.25)
                    .foregroundStyle(statusColor(snapshot))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 18, alignment: .top)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
        } else {
            emptyState(provider: scopedProvider)
        }
    }

    private func smallGauge(_ snapshot: ProviderUsageSnapshot) -> some View {
        let window = snapshot.primaryDisplayWindow
        return ZStack {
            Circle().stroke(UsageTheme.track, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(window.normalizedPercent / 100, 0), 1))
                .stroke(
                    UsageTheme.provider(snapshot.id).opacity(isStale(snapshot) ? 0.52 : 1),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(percent(window.usedPercent))
                    .font(.system(size: 25, weight: .bold))
                    .tracking(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(UsageTheme.primaryText)
                Text(primaryQuotaLabel(snapshot))
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.15)
                    .foregroundStyle(UsageTheme.mutedText)
                Text("\(language.text("RESET", "REINICIA")) \(shortReset(snapshot))")
                    .font(.system(size: 6.5, weight: .semibold, design: .monospaced))
                    .tracking(0.35)
                    .foregroundStyle(UsageTheme.mutedText.opacity(0.85))
            }
        }
        .frame(width: 88, height: 88)
    }

    @ViewBuilder
    private var mediumContent: some View {
        if displayedSnapshots.isEmpty {
            emptyState(provider: nil)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(displayedSnapshots.enumerated()), id: \.element.id) { index, snapshot in
                    if index > 0 {
                        Rectangle().fill(UsageTheme.hairline).frame(width: 1).padding(.vertical, 2)
                    }
                    mediumProvider(snapshot)
                }
            }
            .padding(14)
        }
    }

    private func mediumProvider(_ snapshot: ProviderUsageSnapshot) -> some View {
        let window = snapshot.primaryDisplayWindow
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                ProviderGlyph(provider: snapshot.id, size: 13, color: UsageTheme.secondaryText)
                Text(snapshot.id.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(UsageTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                freshness(snapshot)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(number(window.usedPercent))
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-1)
                if window.usedPercent != nil {
                    Text("%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(UsageTheme.tertiaryText)
                }
                Text(primaryQuotaLabel(snapshot))
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(UsageTheme.mutedText)
                    .padding(.leading, 2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(UsageTheme.primaryText)

            UsageMeter(
                value: window.normalizedPercent,
                severity: UsageSeverity.forPercent(window.usedPercent),
                height: 5
            )
            .opacity(isStale(snapshot) ? 0.55 : 1)

            HStack(spacing: 5) {
                Text(language.text("RESETS", "REINICIA")).tracking(0.85)
                Text(shortReset(snapshot)).monospacedDigit()
                Spacer(minLength: 3)
                if snapshot.session.usedPercent != nil {
                    Text("\(language.text("WK", "SEM")) \(percent(snapshot.weekly.usedPercent))")
                        .foregroundStyle(UsageTheme.quotaText(snapshot.weekly, secondary: true))
                }
            }
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(UsageTheme.mutedText)
            .lineLimit(1)

            Text(statusText(snapshot) ?? " ")
                .font(.system(size: 7.5, weight: .bold))
                .tracking(0.25)
                .foregroundStyle(statusColor(snapshot))
                .lineLimit(2)
                .frame(minHeight: 18, alignment: .topLeading)
        }
        .opacity(isStale(snapshot) ? 0.82 : 1)
        .padding(.horizontal, displayedSnapshots.count == 1 ? 18 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var largeContent: some View {
        if displayedSnapshots.isEmpty {
            emptyState(provider: nil)
        } else {
            VStack(spacing: 0) {
                largeHeader
                if displayedSnapshots.count == 1, let snapshot = displayedSnapshots.first {
                    largeSingleProvider(snapshot)
                } else {
                    ForEach(Array(displayedSnapshots.enumerated()), id: \.element.id) { index, snapshot in
                        largeProviderRow(snapshot)
                        if index < displayedSnapshots.count - 1 { divider }
                    }
                }
                divider
                chartHeader.padding(.top, 11)
                WidgetTrendChart(
                    history: entry.history,
                    now: entry.date,
                    providers: Set(displayedSnapshots.map(\.id))
                )
                .frame(height: displayedSnapshots.count == 1 ? 112 : 88)
                .padding(.top, 4)
                streakFooter.padding(.top, 7)
            }
            .padding(16)
        }
    }

    private var largeHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("RESETPLS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.55)
                .foregroundStyle(UsageTheme.mutedText)
            Spacer()
            Text(entry.date, style: .time)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(UsageTheme.primaryText)
        }
    }

    private func largeProviderRow(_ snapshot: ProviderUsageSnapshot) -> some View {
        let window = snapshot.primaryDisplayWindow
        return VStack(spacing: 7) {
            HStack(spacing: 6) {
                ProviderGlyph(provider: snapshot.id, size: 13, color: UsageTheme.secondaryText)
                Text(snapshot.id.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UsageTheme.primaryText)
                Spacer()
                Text(percent(window.usedPercent))
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(UsageTheme.primaryText)
                Text(primaryQuotaLabel(snapshot))
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(UsageTheme.mutedText)
            }
            UsageMeter(
                value: window.normalizedPercent,
                severity: UsageSeverity.forPercent(window.usedPercent),
                height: 5
            )
            .opacity(isStale(snapshot) ? 0.55 : 1)
            HStack(spacing: 5) {
                Text("\(language.text("RESETS", "REINICIA")) \(shortReset(snapshot))")
                Spacer(minLength: 4)
                if snapshot.session.usedPercent != nil {
                    Text("\(language.text("WEEK", "SEM")) \(percent(snapshot.weekly.usedPercent))")
                }
                if let status = statusText(snapshot) {
                    Text("· \(status)").foregroundStyle(statusColor(snapshot))
                }
            }
            .font(.system(size: 7.5, weight: .semibold))
            .tracking(0.35)
            .foregroundStyle(UsageTheme.mutedText)
            .lineLimit(1)
        }
        .padding(.vertical, 9)
        .opacity(isStale(snapshot) ? 0.82 : 1)
    }

    private func largeSingleProvider(_ snapshot: ProviderUsageSnapshot) -> some View {
        let window = snapshot.primaryDisplayWindow
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProviderGlyph(provider: snapshot.id, size: 15, color: UsageTheme.secondaryText)
                        Text(snapshot.id.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(UsageTheme.primaryText)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(number(window.usedPercent))
                            .font(.system(size: 42, weight: .bold))
                            .tracking(-1.3)
                        if window.usedPercent != nil {
                            Text("%").font(.system(size: 16, weight: .bold))
                                .foregroundStyle(UsageTheme.tertiaryText)
                        }
                        Text(primaryQuotaLabel(snapshot))
                            .font(.system(size: 8.5, weight: .bold))
                            .tracking(1.15)
                            .foregroundStyle(UsageTheme.mutedText)
                    }
                    .foregroundStyle(UsageTheme.primaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(language.text("RESETS IN", "REINICIA EN"))
                        .font(.system(size: 7.5, weight: .bold))
                        .tracking(1.05)
                        .foregroundStyle(UsageTheme.mutedText)
                    Text(shortReset(snapshot))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(UsageTheme.secondaryText)
                }
            }
            .padding(.top, 17)
            UsageMeter(
                value: window.normalizedPercent,
                severity: UsageSeverity.forPercent(window.usedPercent),
                height: 6
            )
            .padding(.top, 9)
            HStack {
                Text(statusText(snapshot) ?? " ")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.55)
                    .foregroundStyle(statusColor(snapshot))
                Spacer()
            }
            .padding(.top, 7)
            .padding(.bottom, 12)
        }
    }

    private var chartHeader: some View {
        HStack {
            Text(language.text("QUOTA · LAST 7 DAYS", "CUOTA · ÚLTIMOS 7 DÍAS"))
                .font(.system(size: 8, weight: .bold))
                .tracking(1.15)
                .foregroundStyle(UsageTheme.mutedText)
            Spacer()
            HStack(spacing: 8) {
                ForEach(displayedSnapshots) { snapshot in
                    HStack(spacing: 3) {
                        Circle().fill(UsageTheme.provider(snapshot.id)).frame(width: 5, height: 5)
                        Text(snapshot.id == .claude ? "Claude" : "Codex")
                    }
                }
            }
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(UsageTheme.mutedText)
        }
    }

    private var streakFooter: some View {
        let count = entry.history.currentStreak(relativeTo: entry.date)
        let days = entry.history.lastSevenDays(relativeTo: entry.date)
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(String(count))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(UsageTheme.green)
                    Text(language.text("DAY STREAK", "RACHA DIARIA"))
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(1.25)
                        .foregroundStyle(UsageTheme.green.opacity(0.72))
                }
                HStack(spacing: 5) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        Circle()
                            .fill(day.hasUsage ? streakColor(Double(index) / 6) : UsageTheme.track)
                            .frame(width: index == 6 ? 7 : 6, height: index == 6 ? 7 : 6)
                            .shadow(
                                color: index == 6 && day.hasUsage ? UsageTheme.green.opacity(0.75) : .clear,
                                radius: 6
                            )
                    }
                }
            }
            Spacer()
            Text("\(language.text("UPDATED", "ACTUALIZADO")) \(latestObservation, style: .time)")
                .font(.system(size: 7.5, weight: .semibold))
                .tracking(0.45)
                .foregroundStyle(UsageTheme.mutedText)
        }
    }

    #if os(iOS)
    @ViewBuilder
    private var circularContent: some View {
        if let snapshot = selectedSnapshot {
            let percentValue = min(max(snapshot.primaryDisplayWindow.normalizedPercent / 100, 0), 1)
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.18), lineWidth: 4.5)
                Circle()
                    .trim(from: 0, to: percentValue)
                    .stroke(
                        .primary.opacity(actionLabel(for: snapshot.id) == nil ? 0.9 : 0.45),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    ProviderGlyph(provider: snapshot.id, size: 9, color: .primary.opacity(0.78))
                    if actionLabel(for: snapshot.id) != nil {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                    } else {
                        Text(percent(snapshot.primaryDisplayWindow.usedPercent))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.72)
                    }
                }
            }
            .padding(3)
            .widgetAccentable()
        } else {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 17, weight: .semibold))
        }
    }

    @ViewBuilder
    private var rectangularContent: some View {
        if displayedSnapshots.isEmpty {
            HStack(spacing: 9) {
                Image(systemName: hasReconnectState ? "person.crop.circle.badge.exclamationmark" : "arrow.clockwise")
                Text(hasReconnectState
                    ? language.text("Open app to reconnect", "Abrir app para reconectar")
                    : language.text("Open app to connect", "Abrir app para conectar"))
                    .fontWeight(.semibold)
                Spacer()
            }
            .font(.system(size: 12))
        } else if displayedSnapshots.count == 1, let snapshot = displayedSnapshots.first {
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    ProviderGlyph(provider: snapshot.id, size: 13, color: .primary.opacity(0.82))
                    Text(snapshot.id.displayName).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(percent(snapshot.primaryDisplayWindow.usedPercent))
                        .font(.system(size: 19, weight: .bold)).monospacedDigit()
                    Text(primaryQuotaLabel(snapshot))
                        .font(.system(size: 7.5, weight: .bold)).tracking(1).opacity(0.58)
                }
                HStack(spacing: 8) {
                    accessoryMeter(snapshot)
                    Text(actionLabel(for: snapshot.id) ?? "\(language.text("RESETS", "REINICIA")) \(shortReset(snapshot))")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .opacity(0.65)
                }
            }
        } else {
            VStack(spacing: 7) {
                ForEach(displayedSnapshots) { snapshot in
                    HStack(spacing: 8) {
                        ProviderGlyph(provider: snapshot.id, size: 13, color: .primary.opacity(0.9))
                        Text(percent(snapshot.primaryDisplayWindow.usedPercent))
                            .font(.system(size: 15, weight: .bold)).monospacedDigit()
                            .frame(width: 40, alignment: .leading)
                        accessoryMeter(snapshot)
                        Text(actionLabel(for: snapshot.id) ?? (isStale(snapshot)
                            ? snapshot.observedAt.formatted(date: .omitted, time: .shortened)
                            : shortReset(snapshot)))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .frame(width: 62, alignment: .trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .opacity(0.8)
                    }
                }
            }
        }
    }

    private func accessoryMeter(_ snapshot: ProviderUsageSnapshot) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.13))
                Capsule()
                    .fill(.primary.opacity(actionLabel(for: snapshot.id) == nil ? 0.78 : 0.4))
                    .frame(width: proxy.size.width * snapshot.primaryDisplayWindow.normalizedPercent / 100)
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private var inlineContent: some View {
        if displayedSnapshots.isEmpty {
            Label(
                hasReconnectState
                    ? language.text("Open app to reconnect", "Abrir app para reconectar")
                    : language.text("Open app to connect", "Abrir app para conectar"),
                systemImage: "arrow.clockwise"
            )
        } else {
            inlineText
        }
    }

    /// The inline host extracts one text payload, not an arbitrary HStack.
    /// Embed bounded image attachments in that payload so both services survive.
    private var inlineText: Text {
        var result = Text("")
        for (index, snapshot) in displayedSnapshots.enumerated() {
            if index > 0 { result = result + Text(" · ") }
            let value = actionLabel(for: snapshot.id)?.lowercased(with: language.locale)
                ?? percent(snapshot.primaryDisplayWindow.usedPercent)
            result = result + Text("\(ProviderGlyph.inlineImage(provider: snapshot.id)) \(value)")
            if displayedSnapshots.count == 1, actionLabel(for: snapshot.id) == nil {
                let time = isStale(snapshot)
                    ? snapshot.observedAt.formatted(date: .omitted, time: .shortened)
                    : shortReset(snapshot)
                result = result + Text("  \(Image(systemName: "clock")) \(time)")
            }
        }
        return result
    }
    #endif

    private func freshness(_ snapshot: ProviderUsageSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isStale(snapshot) ? "clock.fill" : "circle.fill")
                .font(.system(size: isStale(snapshot) ? 7 : 5, weight: .bold))
            Text(snapshot.observedAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 7.5, weight: .bold))
                .tracking(0.45)
        }
        .foregroundStyle(isStale(snapshot) ? UsageTheme.cached : UsageTheme.green.opacity(0.9))
        .fixedSize()
    }

    private func emptyState(provider: UsageProviderID?) -> some View {
        VStack(spacing: 9) {
            Image(systemName: provider?.symbolName ?? "chart.bar.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(UsageTheme.green)
            Text(language.text("Open ResetPls", "Abre ResetPls"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(UsageTheme.primaryText)
            Text(provider.map {
                language.text("Connect \($0.displayName) to see its limits.",
                              "Conecta \($0.displayName) para ver sus límites.")
            } ?? language.text("Connect a service to see its limits.",
                               "Conecta un servicio para ver sus límites."))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UsageTheme.mutedText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var scopedProvider: UsageProviderID? {
        if case .provider(let provider) = scope { return provider }
        return nil
    }

    private var selectedSnapshot: ProviderUsageSnapshot? {
        if let scopedProvider { return entry.snapshots.first { $0.id == scopedProvider } }
        return displayedSnapshots.first
    }

    private var displayedSnapshots: [ProviderUsageSnapshot] {
        let ordered = ProviderOrderPreferences.ordered().compactMap { provider in
            entry.snapshots.first { $0.id == provider }
        }
        if let scopedProvider { return ordered.filter { $0.id == scopedProvider } }
        return ordered
    }

    private var actionProvider: UsageProviderID? {
        displayedSnapshots.first { actionLabel(for: $0.id) != nil }?.id
    }

    private var hasReconnectState: Bool {
        entry.states.values.contains(.reauthRequired)
    }

    private var latestObservation: Date {
        displayedSnapshots.map(\.observedAt).max() ?? entry.date
    }

    private var divider: some View {
        Rectangle().fill(UsageTheme.hairline).frame(height: 1)
    }

    private func actionLabel(for provider: UsageProviderID) -> String? {
        switch entry.states[provider] {
        case .setupRequired: language.text("CONNECT", "CONECTA")
        case .reauthRequired: language.text("RECONNECT", "RECONECTA")
        case .temporarilyUnavailable: language.text("TRY AGAIN", "REINTENTA")
        case .live, .cached, .stale, .none: nil
        }
    }

    private func statusText(_ snapshot: ProviderUsageSnapshot) -> String? {
        if let action = actionLabel(for: snapshot.id) { return action }
        if isStale(snapshot) {
            return language.text("UPDATE FAILED · OPEN APP", "FALLO AL ACTUALIZAR · ABRE LA APP")
        }
        return snapshot.preferredPaceNotice(at: entry.date).map(language.paceNoticeText)
    }

    private func statusColor(_ snapshot: ProviderUsageSnapshot) -> Color {
        if actionLabel(for: snapshot.id) != nil || isStale(snapshot) { return UsageTheme.cached }
        switch snapshot.preferredPaceNotice(at: entry.date) {
        case .weekly(let risk):
            guard snapshot.primaryQuotaID == .weekly else { return UsageTheme.mutedText }
            switch risk.state {
            case .roomToSpare, .onTrack: return UsageTheme.mutedText
            case .atRisk: return UsageTheme.amber
            case .highRisk: return UsageTheme.red
            }
        case .session(.limitIn): return UsageTheme.amber
        case .session, nil: return UsageTheme.mutedText
        }
    }

    private func number(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(Int(value.rounded()))
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    private func primaryQuotaLabel(_ snapshot: ProviderUsageSnapshot) -> String {
        snapshot.session.usedPercent == nil ? language.text("WEEK", "SEMANA")
                                            : language.text("SESSION", "SESIÓN")
    }

    private func isStale(_ snapshot: ProviderUsageSnapshot) -> Bool {
        snapshot.source == .cached || snapshot.isStale(at: entry.date)
    }

    private func shortReset(_ snapshot: ProviderUsageSnapshot) -> String {
        UsageResetFormatter.string(until: snapshot.availabilityReset, relativeTo: entry.date)
    }

    private func streakColor(_ progress: Double) -> Color {
        Color(
            red: (18 + (62 - 18) * progress) / 255,
            green: (59 + (207 - 59) * progress) / 255,
            blue: (48 + (142 - 48) * progress) / 255
        )
    }
}

private struct WidgetTrendChart: View {
    let history: UsageHistory
    let now: Date
    let providers: Set<UsageProviderID>

    private var days: [UsageHistoryDay] { history.lastSevenDays(relativeTo: now) }

    var body: some View {
        Canvas { context, size in
            let top: CGFloat = 10
            let baseline = size.height - 17
            let plotHeight = max(baseline - top, 1)

            for fraction in [CGFloat(0), 0.5] {
                var grid = Path()
                let y = top + plotHeight * fraction
                grid.move(to: CGPoint(x: 3, y: y))
                grid.addLine(to: CGPoint(x: size.width - 3, y: y))
                context.stroke(
                    grid,
                    with: .color(Color.white.opacity(fraction == 0 ? 0.1 : 0.07)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 7])
                )
            }

            if providers.contains(.claude) {
                drawSeries(.claude, color: UsageTheme.claude, size: size, top: top,
                           baseline: baseline, plotHeight: plotHeight, context: &context)
            }
            if providers.contains(.codex) {
                drawSeries(.codex, color: UsageTheme.codex, size: size, top: top,
                           baseline: baseline, plotHeight: plotHeight, context: &context)
            }

            for (index, day) in days.enumerated() {
                let x = xPosition(index, width: size.width)
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 1.5, y: baseline - 1.5, width: 3, height: 3)),
                    with: .color(Color.white.opacity(0.2))
                )
                context.draw(
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(UsageTheme.mutedText),
                    at: CGPoint(x: x, y: size.height - 4),
                    anchor: .center
                )
            }
        }
    }

    private func drawSeries(
        _ provider: UsageProviderID,
        color: Color,
        size: CGSize,
        top: CGFloat,
        baseline: CGFloat,
        plotHeight: CGFloat,
        context: inout GraphicsContext
    ) {
        var segment: [CGPoint] = []
        for (index, day) in days.enumerated() {
            guard let value = day.percent(for: provider), value.isFinite else {
                drawSegment(segment, color: color, baseline: baseline, top: top, context: &context)
                segment.removeAll(keepingCapacity: true)
                continue
            }
            segment.append(CGPoint(
                x: xPosition(index, width: size.width),
                y: baseline - plotHeight * CGFloat(min(max(value, 0), 100)) / 100
            ))
        }
        drawSegment(segment, color: color, baseline: baseline, top: top, context: &context)
    }

    private func drawSegment(
        _ points: [CGPoint],
        color: Color,
        baseline: CGFloat,
        top: CGFloat,
        context: inout GraphicsContext
    ) {
        guard let first = points.first else { return }
        if points.count > 1, let last = points.last {
            let line = smoothPath(points)
            var area = line
            area.addLine(to: CGPoint(x: last.x, y: baseline))
            area.addLine(to: CGPoint(x: first.x, y: baseline))
            area.closeSubpath()
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.18), color.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: top),
                    endPoint: CGPoint(x: 0, y: baseline)
                )
            )
            context.stroke(
                line,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
            )
        }
        for (index, point) in points.enumerated() {
            let isLast = index == points.count - 1
            if isLast {
                context.stroke(
                    Path(ellipseIn: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11)),
                    with: .color(color.opacity(0.32)),
                    lineWidth: 1.4
                )
            }
            let radius: CGFloat = isLast ? 3 : 1.9
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                      width: radius * 2, height: radius * 2)),
                with: .color(color)
            )
        }
    }

    private func xPosition(_ index: Int, width: CGFloat) -> CGFloat {
        3 + (width - 6) * CGFloat(index) / CGFloat(max(days.count - 1, 1))
    }

    private func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 0..<(points.count - 1) {
            let previous = index > 0 ? points[index - 1] : points[index]
            let current = points[index]
            let next = points[index + 1]
            let following = index + 2 < points.count ? points[index + 2] : next
            path.addCurve(
                to: next,
                control1: CGPoint(
                    x: current.x + (next.x - previous.x) / 6,
                    y: current.y + (next.y - previous.y) / 6
                ),
                control2: CGPoint(
                    x: next.x - (following.x - current.x) / 6,
                    y: next.y - (following.y - current.y) / 6
                )
            )
        }
        return path
    }
}

private struct SummaryUsageWidget: Widget {
    let kind = AIUsageWidgetKind.summary
    private var language: AppLanguage { .current }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageWidgetProvider()) { entry in
            UsageWidgetView(entry: entry, scope: .summary)
        }
        .configurationDisplayName("ResetPls")
        .description(language.text("Your Claude and Codex limits at a glance.",
                                   "Tus límites de Claude y Codex de un vistazo."))
        #if os(iOS)
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        #else
        .supportedFamilies([.systemMedium, .systemLarge])
        #endif
        .contentMarginsDisabled()
    }
}

private struct ProviderUsageWidget: Widget {
    private var language: AppLanguage { .current }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: AIUsageWidgetKind.provider,
            intent: ProviderWidgetIntent.self,
            provider: ProviderWidgetTimelineProvider()
        ) { entry in
            UsageWidgetView(entry: entry, scope: .summary)
        }
        .configurationDisplayName("ResetPls · Service")
        .description(language.text("The selected service, with room to breathe.",
                                   "El servicio seleccionado, con espacio para respirar."))
        #if os(iOS)
        .supportedFamilies([.systemSmall, .accessoryCircular])
        #else
        .supportedFamilies([.systemSmall])
        #endif
        .contentMarginsDisabled()
    }
}

@main
struct AIUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        SummaryUsageWidget()
        ProviderUsageWidget()
    }
}
