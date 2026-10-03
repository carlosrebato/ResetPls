import AIUsageCore
import Foundation
import SwiftUI

public struct UsageCompactMetrics: View {
    public let snapshots: [ProviderUsageSnapshot]
    public let now: Date
    public let language: AppLanguage

    public init(
        snapshots: [ProviderUsageSnapshot],
        now: Date,
        language: AppLanguage = .english
    ) {
        self.snapshots = snapshots
        self.now = now
        self.language = language
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, snapshot in
                if index > 0 {
                    Rectangle()
                        .fill(UsageTheme.hairline)
                        .frame(width: 1)
                        .padding(.vertical, 2)
                }
                compactColumn(snapshot)
            }
        }
    }

    private var ordered: [ProviderUsageSnapshot] {
        snapshots
    }

    private func compactColumn(_ snapshot: ProviderUsageSnapshot) -> some View {
        let primary = snapshot.primaryDisplayWindow

        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                ProviderGlyph(provider: snapshot.id, size: 15)
                Text(snapshot.id.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UsageTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if snapshot.source == .cached || snapshot.isStale(at: now) {
                    Label {
                        Text(snapshot.observedAt.formatted(date: .omitted, time: .shortened))
                    } icon: {
                        Image(systemName: "clock.fill")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(UsageTheme.cached)
                    .accessibilityLabel(language.text(
                        "Last saved value from \(snapshot.observedAt.formatted(date: .omitted, time: .shortened))",
                        "Último dato guardado de las \(snapshot.observedAt.formatted(date: .omitted, time: .shortened))"
                    ))
                    .fixedSize(horizontal: true, vertical: false)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(percentNumber(primary.usedPercent))
                    .font(.system(size: 46, weight: .bold))
                    .tracking(-1.8)
                    .monospacedDigit()
                    .foregroundStyle(UsageTheme.quotaText(primary))
                if primary.usedPercent != nil {
                    Text("%")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(UsageTheme.tertiaryText)
                }
                Text(primaryPeriodLabel(snapshot, language: language))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(UsageTheme.mutedText)
                    .padding(.leading, 4)
            }

            UsageMeter(
                value: primary.normalizedPercent,
                severity: UsageSeverity.forPercent(primary.usedPercent)
            )

            HStack(spacing: 5) {
                Text(language.resetLabel(for: snapshot)).foregroundStyle(UsageTheme.availabilityText(snapshot))
                Text(UsageResetFormatter.string(until: snapshot.availabilityReset, relativeTo: now))
                    .foregroundStyle(UsageTheme.availabilityText(snapshot))
                if snapshot.session.usedPercent != nil {
                    Text("·").foregroundStyle(UsageTheme.mutedText)
                    microLabel(language.text("WK", "SEM"))
                    Text(percent(snapshot.weekly.usedPercent))
                        .foregroundStyle(UsageTheme.quotaText(snapshot.weekly, secondary: true))
                }
            }
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.45)
            .monospacedDigit()
            .lineLimit(1)
            UsagePaceLine(snapshot: snapshot, now: now, language: language)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func microLabel(_ text: String) -> Text {
        Text(text).foregroundStyle(UsageTheme.mutedText)
    }

}

public struct UsageDetailedMetrics: View {
    public let snapshots: [ProviderUsageSnapshot]
    public let now: Date
    public let history: UsageHistory
    public let language: AppLanguage
    public let verticalExpansion: CGFloat
    public let persistentPace: Bool

    public init(
        snapshots: [ProviderUsageSnapshot],
        now: Date,
        history: UsageHistory = UsageHistory(),
        language: AppLanguage = .english,
        verticalExpansion: CGFloat = 0,
        persistentPace: Bool = true
    ) {
        self.snapshots = snapshots
        self.now = now
        self.history = history
        self.language = language
        self.verticalExpansion = verticalExpansion
        self.persistentPace = persistentPace
    }

    public var body: some View {
        VStack(spacing: 20 + verticalExpansion * 0.12) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, snapshot in
                if index > 0 {
                    Rectangle().fill(UsageTheme.hairline).frame(height: 1)
                }
                providerBlock(snapshot)
            }

            UsageTrendFooter(
                history: history,
                now: now,
                language: language,
                providers: Set(ordered.map(\.id)),
                providerOrder: ordered.map(\.id),
                currentDayProviders: Set(
                    ordered.filter { $0.source != .unavailable && $0.highestPercent != nil }
                        .map(\.id)
                ),
                verticalExpansion: verticalExpansion
            )
        }
    }

    private var ordered: [ProviderUsageSnapshot] {
        snapshots
    }

    private func providerBlock(_ snapshot: ProviderUsageSnapshot) -> some View {
        let primary = snapshot.primaryDisplayWindow
        let signal = snapshot.signal(at: now)

        return VStack(alignment: .leading, spacing: 11 + verticalExpansion * 0.08) {
            HStack(spacing: 10) {
                ProviderGlyph(provider: snapshot.id, size: 16)
                Text(snapshot.id.displayName)
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(UsageTheme.primaryText)
                Spacer()
                UsageStatusDot(
                    severity: signal == .critical ? .critical : .normal,
                    color: UsageTheme.signal(signal),
                    size: 8
                )
            }

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(percentNumber(primary.usedPercent))
                            .font(.system(size: 46, weight: .bold))
                            .tracking(-1.8)
                            .monospacedDigit()
                            .foregroundStyle(UsageTheme.quotaText(primary))
                        if primary.usedPercent != nil {
                            Text("%")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(UsageTheme.tertiaryText)
                        }
                        Text(primaryPeriodLabel(snapshot, language: language))
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.15)
                            .foregroundStyle(UsageTheme.mutedText)
                            .padding(.leading, 4)
                    }
                    UsageMeter(
                        value: primary.normalizedPercent,
                        severity: UsageSeverity.forPercent(primary.usedPercent)
                    )
                }

                if snapshot.session.usedPercent != nil {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(percentNumber(snapshot.weekly.usedPercent))
                                .font(.system(size: 26, weight: .bold))
                                .tracking(-0.7)
                                .monospacedDigit()
                                .foregroundStyle(UsageTheme.quotaText(snapshot.weekly, secondary: true))
                                .fixedSize()
                            if snapshot.weekly.usedPercent != nil {
                                Text("%")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(UsageTheme.tertiaryText)
                            }
                            Text(language.text("WK", "SEM"))
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(UsageTheme.mutedText)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        UsageMeter(value: snapshot.weekly.normalizedPercent, severity: UsageSeverity.forPercent(snapshot.weekly.usedPercent))
                    }
                    .frame(width: 78)
                }
            }

            HStack(spacing: 14) {
                metric(
                    label: language.resetLabel(for: snapshot),
                    value: UsageResetFormatter.string(until: snapshot.availabilityReset, relativeTo: now),
                    color: snapshot.availability == .available ? nil : UsageTheme.red
                )
                TokenDetailMetric(
                    label: "TOKENS",
                    value: snapshot.weeklyTotals.map { compactTokens($0.totalTokens) } ?? "—",
                    help: snapshot.weeklyTotals.map {
                        tokenBreakdown($0, language: language)
                    } ?? missingLocalHistoryHelp(language: language)
                )
                .zIndex(1)
                Spacer()
                if snapshot.source == .cached {
                    Label {
                        Text(snapshot.observedAt.formatted(date: .omitted, time: .shortened))
                    } icon: {
                        Image(systemName: "clock.fill")
                    }
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(UsageTheme.cached)
                        .accessibilityLabel(language.text(
                            "Last saved value from \(snapshot.observedAt.formatted(date: .omitted, time: .shortened))",
                            "Último dato guardado de las \(snapshot.observedAt.formatted(date: .omitted, time: .shortened))"
                        ))
                        .fixedSize(horizontal: true, vertical: false)
                } else if snapshot.source == .unavailable {
                    Text(language.text("OFFLINE", "SIN CONEXIÓN"))
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(UsageTheme.red)
                }
            }
            UsagePaceLine(
                snapshot: snapshot,
                now: now,
                language: language,
                persistentSessionStatus: persistentPace
            )
        }
        .padding(.vertical, verticalExpansion * 0.3)
    }

    private func metric(label: String, value: String, color: Color? = nil) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(color ?? UsageTheme.mutedText)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color ?? UsageTheme.metaText)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

}

private struct TokenDetailMetric: View {
    let label: String
    let value: String
    let help: String
    @State private var isHovered = false
    @State private var showsDetails = false

    private var metric: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(UsageTheme.mutedText)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(UsageTheme.metaText)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        Button { showsDetails = true } label: { metric }
            .buttonStyle(.plain)
            .popover(isPresented: $showsDetails) {
                Text(help)
                    .font(.footnote)
                    .foregroundStyle(UsageTheme.primaryText)
                    .padding(16)
                    .frame(maxWidth: 280, alignment: .leading)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityHint(help)
        #else
        metric
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .overlay(alignment: .bottomLeading) {
                if isHovered {
                    Text(help)
                        .font(.system(size: 11))
                        .foregroundStyle(UsageTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 250, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(UsageTheme.stage)
                                .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(UsageTheme.hairline, lineWidth: 1)
                        }
                        .offset(y: -24)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityHint(help)
        #endif
    }
}

public struct UsageTrendFooter: View {
    public let history: UsageHistory
    public let now: Date
    public let language: AppLanguage
    public let providers: Set<UsageProviderID>
    public let providerOrder: [UsageProviderID]
    public let currentDayProviders: Set<UsageProviderID>
    public let verticalExpansion: CGFloat
    public let compact: Bool

    public init(
        history: UsageHistory,
        now: Date,
        language: AppLanguage = .english,
        providers: Set<UsageProviderID> = Set(UsageProviderID.allCases),
        providerOrder: [UsageProviderID] = UsageProviderID.allCases,
        currentDayProviders: Set<UsageProviderID> = Set(UsageProviderID.allCases),
        verticalExpansion: CGFloat = 0,
        compact: Bool = false
    ) {
        self.history = history
        self.now = now
        self.language = language
        self.providers = providers
        self.providerOrder = providerOrder
        self.currentDayProviders = currentDayProviders
        self.verticalExpansion = verticalExpansion
        self.compact = compact
    }

    public var body: some View {
        let trend = UsageTrend(
            days: history.lastSevenDays(relativeTo: now, currentDayProviders: currentDayProviders),
            providers: providers
        )
        VStack(spacing: compact ? 8 : 14) {
            HStack {
                Text(trend.metric == .tokens
                    ? language.text("TOKENS · LAST 7 DAYS", "TOKENS · ÚLTIMOS 7 DÍAS")
                    : language.text("QUOTA · LAST 7 DAYS", "CUOTA · ÚLTIMOS 7 DÍAS"))
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.15)
                    .foregroundStyle(UsageTheme.mutedText)

                Spacer()

                ForEach(providerOrder.filter { providers.contains($0) }, id: \.self) { provider in
                    legend(provider, trend: trend)
                }
            }

            UsageTrendChart(
                trend: trend,
                language: language
            )
            .frame(height: (compact ? 52 : 100) + (verticalExpansion * 6))

            streak
                .padding(.top, compact ? 0 : 2)
        }
        .padding(.top, compact ? 9 : 16)
        .overlay(alignment: .top) {
            Rectangle().fill(UsageTheme.hairline).frame(height: 1)
        }
    }

    private func legend(_ provider: UsageProviderID, trend: UsageTrend) -> some View {
        let title = provider == .claude ? "Claude" : "Codex"
        let color = UsageTheme.provider(provider)
        let isAvailable = trend.hasSeries(for: provider)
        let value = trend.days.last.flatMap { trend.value(for: $0, provider: provider) }
        let formatted = value.map {
            trend.metric == .tokens ? compactTokens(Int($0)) : "\(Int($0.rounded()))%"
        } ?? "—"
        let unit = trend.metric == .tokens ? " tokens" : ""

        return HStack(spacing: 5) {
            Circle().fill(color.opacity(isAvailable ? 1 : 0.4)).frame(width: 6, height: 6)
            Text(value == nil ? "\(title) —" : title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(UsageTheme.tertiaryText)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value == nil ? language.text(
            "\(title): no measurement today",
            "\(title): sin medición hoy"
        ) : language.text(
            "\(title), today: \(formatted)\(unit)",
            "\(title), hoy: \(formatted)\(unit)"
        ))
    }

    private var streak: some View {
        let count = history.currentStreak(relativeTo: now)
        let today = history.lastSevenDays(relativeTo: now).last
        let hasEvidence = today?.activity != nil
            || today?.claudeTokens != nil || today?.codexTokens != nil
        let visibleCount = min(count, 15)

        return VStack(spacing: compact ? 6 : 11) {
            HStack(alignment: .firstTextBaseline, spacing: compact ? 6 : 8) {
                Text(hasEvidence ? String(count) : "—")
                    .font(.system(size: compact ? 21 : 28, weight: .bold))
                    .tracking(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(UsageTheme.green)
                Text(language.text("DAY STREAK", "RACHA DIARIA"))
                    .font(.system(size: compact ? 8 : 9, weight: .semibold))
                    .tracking(1.15)
                    .foregroundStyle(Color(red: 90 / 255, green: 143 / 255, blue: 119 / 255))
            }

            HStack(spacing: compact ? 5 : 7) {
                ForEach(0..<visibleCount, id: \.self) { index in
                    let progress = visibleCount == 1
                        ? 1
                        : Double(index) / Double(visibleCount - 1)
                    Circle()
                        .fill(streakColor(progress))
                        .frame(
                            width: index == visibleCount - 1 ? (compact ? 6 : 8) : (compact ? 5 : 7),
                            height: index == visibleCount - 1 ? (compact ? 6 : 8) : (compact ? 5 : 7)
                        )
                        .shadow(
                            color: index == visibleCount - 1
                                ? UsageTheme.green.opacity(0.9)
                                : .clear,
                            radius: 10
                        )
                }
            }
        }
    }

    private func streakColor(_ progress: Double) -> Color {
        let start = (r: 18.0, g: 59.0, b: 48.0)
        let end = (r: 62.0, g: 207.0, b: 142.0)
        return Color(
            red: (start.r + (end.r - start.r) * progress) / 255,
            green: (start.g + (end.g - start.g) * progress) / 255,
            blue: (start.b + (end.b - start.b) * progress) / 255
        )
    }
}

private struct UsageTrendChart: View {
    let trend: UsageTrend
    let language: AppLanguage

    private var days: [UsageHistoryDay] { trend.days }
    private var providers: Set<UsageProviderID> { trend.providers }

    var body: some View {
        Canvas { context, size in
            let left: CGFloat = 3
            let endpointLabels = makeEndpointLabels(context: context)
            let labelWidth = endpointLabels.map { $0.size.width }.max() ?? 0
            // Keep only the width the endpoint value actually needs. The previous
            // generous gutter made the seven-day series look horizontally cropped.
            let labelGutter = endpointLabels.isEmpty ? 8 : labelWidth + 6
            let right = max(left, size.width - labelGutter)
            let top: CGFloat = 16
            let baseline = max(top + 36, size.height - 22)
            let plotHeight = baseline - top
            let step = (right - left) / CGFloat(max(days.count - 1, 1))
            let xPositions = days.indices.map { left + CGFloat($0) * step }
            let hasMeasurements = providers.contains { trend.hasSeries(for: $0) }
            if hasMeasurements {
                context.draw(
                    Text(trend.metric == .tokens ? compactTokens(Int(trend.scaleMaximum)) : "100%")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(UsageTheme.mutedText),
                    at: CGPoint(x: left, y: 4),
                    anchor: .topLeading
                )
            } else {
                context.draw(
                    Text(language.text("No measurements", "Sin mediciones"))
                        .font(.system(size: 10))
                        .foregroundStyle(UsageTheme.mutedText),
                        at: CGPoint(x: size.width / 2, y: size.height / 2)
                )
            }

            drawDottedGuide(in: &context, from: left, to: right, y: top, opacity: 0.13)
            drawDottedGuide(
                in: &context,
                from: left,
                to: right,
                y: top + plotHeight / 2,
                opacity: 0.09
            )

            if providers.contains(.claude) {
                drawSeries(
                    provider: .claude,
                    color: UsageTheme.claude,
                    areaOpacity: 0.22,
                    xPositions: xPositions,
                    baseline: baseline,
                    plotHeight: plotHeight,
                    context: &context
                )
            }
            if providers.contains(.codex) {
                drawSeries(
                    provider: .codex,
                    color: UsageTheme.codex,
                    areaOpacity: 0.18,
                    xPositions: xPositions,
                    baseline: baseline,
                    plotHeight: plotHeight,
                    context: &context
                )
            }

            drawEndpointLabels(
                endpointLabels,
                plotRight: right,
                top: top,
                baseline: baseline,
                size: size,
                context: &context
            )

            for index in days.indices {
                let dotRect = CGRect(
                    x: xPositions[index] - 2,
                    y: baseline - 2,
                    width: 4,
                    height: 4
                )
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(Color.white.opacity(0.2))
                )

                let label = weekdayInitial(days[index].date)
                context.draw(
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(UsageTheme.mutedText),
                    at: CGPoint(x: xPositions[index], y: size.height - 7),
                    anchor: .center
                )
            }
        }
    }

    private func drawDottedGuide(
        in context: inout GraphicsContext,
        from start: CGFloat,
        to end: CGFloat,
        y: CGFloat,
        opacity: Double
    ) {
        var x = start
        while x <= end {
            context.fill(
                Path(ellipseIn: CGRect(x: x - 1.1, y: y - 1.1, width: 2.2, height: 2.2)),
                with: .color(Color.white.opacity(opacity))
            )
            x += 8
        }
    }

    private func drawSeries(
        provider: UsageProviderID,
        color: Color,
        areaOpacity: Double,
        xPositions: [CGFloat],
        baseline: CGFloat,
        plotHeight: CGFloat,
        context: inout GraphicsContext
    ) {
        for segment in trend.segments(for: provider) {
            let points = segment.compactMap { index -> CGPoint? in
                guard let normalized = trend.normalizedValue(for: days[index], provider: provider)
                else { return nil }
                return CGPoint(x: xPositions[index], y: baseline - plotHeight * normalized)
            }
            guard points.count > 1, let first = points.first, let last = points.last else { continue }
            var line = Path()
            line.move(to: first)
            for point in points.dropFirst() { line.addLine(to: point) }

            var area = line
            area.addLine(to: CGPoint(x: last.x, y: baseline))
            area.addLine(to: CGPoint(x: first.x, y: baseline))
            area.closeSubpath()
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(areaOpacity), color.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: 16),
                    endPoint: CGPoint(x: 0, y: baseline)
                )
            )
            context.stroke(
                line,
                with: .color(provider == .codex ? color.opacity(0.85) : color),
                style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round)
            )
        }

        for index in days.indices {
            guard let normalized = trend.normalizedValue(for: days[index], provider: provider)
            else { continue }
            let point = CGPoint(x: xPositions[index], y: baseline - plotHeight * normalized)
            let isToday = index == days.count - 1
            if isToday {
                let ringRadius: CGFloat = provider == .claude ? 7.5 : 6.8
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: point.x - ringRadius,
                        y: point.y - ringRadius,
                        width: ringRadius * 2,
                        height: ringRadius * 2
                    )),
                    with: .color(color.opacity(0.35)),
                    lineWidth: 2
                )
            }
            let radius: CGFloat = isToday ? (provider == .claude ? 4 : 3.6) : 2.3
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color(color)
            )

        }
    }

    private struct EndpointLabel {
        let provider: UsageProviderID
        let normalizedValue: Double
        let text: GraphicsContext.ResolvedText
        let size: CGSize
    }

    private func makeEndpointLabels(context: GraphicsContext) -> [EndpointLabel] {
        guard let today = days.last else { return [] }
        return UsageProviderID.allCases.compactMap { provider in
            guard let value = trend.value(for: today, provider: provider),
                  let normalized = trend.normalizedValue(for: today, provider: provider)
            else { return nil }
            let formatted = trend.metric == .tokens
                ? compactTokens(Int(value)) : "\(Int(value.rounded()))%"
            let resolved = context.resolve(
                Text(formatted)
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(UsageTheme.provider(provider).opacity(0.85))
            )
            return EndpointLabel(
                provider: provider,
                normalizedValue: normalized,
                text: resolved,
                size: resolved.measure(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
            )
        }
    }

    private func drawEndpointLabels(
        _ labels: [EndpointLabel],
        plotRight: CGFloat,
        top: CGFloat,
        baseline: CGFloat,
        size: CGSize,
        context: inout GraphicsContext
    ) {
        let targets = labels.map { label in
            let y = baseline - (baseline - top) * label.normalizedValue
            return CGRect(x: plotRight + 5, y: y - label.size.height / 2,
                          width: label.size.width, height: label.size.height)
        }
        let bounds = CGRect(x: plotRight + 5, y: 4,
                            width: max(0, size.width - plotRight - 5),
                            height: baseline + 4 - 4)
        let frames = UsageTrendLabelLayout.frames(for: targets, in: bounds)
        for (label, frame) in zip(labels, frames) {
            let pointY = baseline - (baseline - top) * label.normalizedValue
            // A faint connector keeps displaced labels attached to their point.
            if abs(frame.midY - pointY) > 2 {
                var connector = Path()
                connector.move(to: CGPoint(x: plotRight + 3, y: pointY))
                connector.addLine(to: CGPoint(x: frame.minX - 2, y: frame.midY))
                context.stroke(connector,
                               with: .color(UsageTheme.provider(label.provider).opacity(0.3)),
                               lineWidth: 0.75)
            }
            context.draw(label.text, at: frame.origin, anchor: .topLeading)
        }
    }

    private func weekdayInitial(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateFormat = "EEEEE"
        return String(formatter.string(from: date).prefix(1)).uppercased(with: language.locale)
    }
}

public struct UsageFloatingMetrics: View {
    public let snapshots: [ProviderUsageSnapshot]
    public let now: Date
    public let language: AppLanguage

    public init(
        snapshots: [ProviderUsageSnapshot],
        now: Date,
        language: AppLanguage = .english
    ) {
        self.snapshots = snapshots
        self.now = now
        self.language = language
    }

    public var body: some View {
        VStack(spacing: 15) {
            ForEach(ordered) { snapshot in
                let primary = snapshot.primaryDisplayWindow

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        ProviderGlyph(provider: snapshot.id, size: 13)
                        Text(snapshot.id == .claude ? "Claude" : "Codex")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(UsageTheme.secondaryText)
                        Spacer()
                        if snapshot.source == .cached {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(UsageTheme.cached)
                                .accessibilityLabel(language.text(
                                    "Cached data",
                                    "Datos en caché"
                                ))
                        }
                        Text(percent(primary.usedPercent))
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(UsageTheme.quotaText(primary))
                    }
                    UsageMeter(
                        value: primary.normalizedPercent,
                        severity: UsageSeverity.forPercent(primary.usedPercent),
                        height: 5
                    )
                    Text(
                        "\(language.resetLabel(for: snapshot)) \(UsageResetFormatter.string(until: snapshot.availabilityReset, relativeTo: now))"
                    )
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.7)
                        .monospacedDigit()
                        .foregroundStyle(UsageTheme.availabilityText(snapshot))
                    UsagePaceLine(snapshot: snapshot, now: now, language: language)
                }
            }
        }
    }

    private var ordered: [ProviderUsageSnapshot] {
        snapshots
    }

}

struct UsagePaceLine: View {
    let snapshot: ProviderUsageSnapshot
    let now: Date
    let language: AppLanguage
    var persistentSessionStatus = true

    @ViewBuilder
    var body: some View {
        let estimate = snapshot.session.usedPercent != nil
            ? snapshot.sessionPaceEstimate(at: now)
            : snapshot.paceEstimate(at: now)
        let weeklyRisk = snapshot.weeklyRisk(at: now)
        if persistentSessionStatus && weeklyRisk == nil && snapshot.session.usedPercent != nil {
            HStack(spacing: 6) {
                Circle()
                    .fill(persistentColor(estimate).opacity(0.9))
                    .frame(width: 5, height: 5)
                Text(persistentText(estimate))
                    .monospacedDigit()
            }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(persistentColor(estimate))
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 14, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                if let text = sessionPaceText(estimate, hasWeeklyRisk: weeklyRisk != nil) {
                    Text(text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(sessionPaceColor(estimate))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let weeklyRisk {
                    WeeklyRiskLine(
                        text: language.weeklyRiskText(weeklyRisk),
                        help: language.weeklyRiskHelp(weeklyRisk),
                        color: weeklyRiskColor(weeklyRisk.state)
                    )
                }
            }
        }
    }

    private func sessionPaceText(_ estimate: PaceEstimate?, hasWeeklyRisk: Bool) -> String? {
        switch estimate {
        case .limitIn(_, quota: .session): language.paceText(estimate)
        case .limitIn(_, quota: .weekly) where !hasWeeklyRisk && snapshot.session.usedPercent == nil:
            language.paceText(estimate)
        case .onTrackToReset where !hasWeeklyRisk && snapshot.session.usedPercent != nil:
            language.paceText(estimate)
        default: nil
        }
    }

    private func sessionPaceColor(_ estimate: PaceEstimate?) -> Color {
        if case .limitIn = estimate { return UsageTheme.amber }
        return UsageTheme.mutedText
    }

    private func persistentText(_ estimate: PaceEstimate?) -> String {
        switch estimate {
        case .limitIn(let duration, let quota):
            let scope = quota == .weekly
                ? language.text("weekly limit", "límite semanal")
                : language.text("this session", "esta sesión")
            return language.text(
                "Not on track for \(scope) · limit in \(UsagePaceFormatter.string(duration: duration))",
                "Ritmo alto para \(scope) · límite en \(UsagePaceFormatter.string(duration: duration))"
            )
        case .onTrackToReset:
            return language.text("On track for this session", "Buen ritmo para esta sesión")
        case .insufficientData:
            return language.text(
                "Session pace · Not enough data yet",
                "Ritmo de sesión · Aún no hay datos suficientes"
            )
        case nil:
            return snapshot.source == .mock
                ? language.text(
                    "Session pace · Not enough data yet",
                    "Ritmo de sesión · Aún no hay datos suficientes"
                )
                : language.text("Session pace unavailable", "Ritmo de sesión no disponible")
        }
    }

    private func persistentColor(_ estimate: PaceEstimate?) -> Color {
        switch estimate {
        case .limitIn: UsageTheme.amber
        case .onTrackToReset: UsageTheme.green.opacity(0.82)
        case .insufficientData, nil: UsageTheme.mutedText
        }
    }

    private func weeklyRiskColor(_ state: WeeklyRiskState) -> Color {
        switch state {
        case .roomToSpare, .onTrack: UsageTheme.mutedText
        case .atRisk: UsageTheme.amber
        case .highRisk: UsageTheme.red
        }
    }
}

private struct WeeklyRiskLine: View {
    let text: String
    let help: String
    let color: Color
    @State private var showsHelp = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            #if os(macOS)
            .onHover { showsHelp = $0 }
            #else
            .onTapGesture { showsHelp.toggle() }
            #endif
            .overlay(alignment: .bottomLeading) {
                if showsHelp {
                    Text(help)
                        .font(.system(size: 11))
                        .foregroundStyle(UsageTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 250, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(UsageTheme.stage)
                                .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(UsageTheme.hairline, lineWidth: 1)
                        }
                        .offset(y: -24)
                        .allowsHitTesting(false)
                    }
            }
            .accessibilityHint(help)
    }
}

public struct UsageMeter: View {
    public let value: Double
    public let severity: UsageSeverity
    public let height: CGFloat

    public init(value: Double, severity: UsageSeverity, height: CGFloat = 6) {
        self.value = value
        self.severity = severity
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(UsageTheme.track)
                Capsule()
                    .fill(UsageTheme.severity(severity))
                    .frame(width: geometry.size.width * min(max(value, 0), 100) / 100)
            }
        }
        .frame(height: height)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.5), value: value)
    }
}

public struct UsageStatusDot: View {
    public let severity: UsageSeverity
    public let color: Color?
    public let size: CGFloat

    public init(severity: UsageSeverity, color: Color? = nil, size: CGFloat = 7) {
        self.severity = severity
        self.color = color
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: severity == .critical ? 0.05 : 1, paused: severity != .critical)) { timeline in
            let pulse = (sin(timeline.date.timeIntervalSinceReferenceDate * .pi * 2) + 1) / 2
            let resolvedColor = color ?? UsageTheme.severity(severity)
            Circle()
                .fill(resolvedColor)
                .frame(width: size, height: size)
                .opacity(severity == .critical ? 0.45 + pulse * 0.55 : 1)
                .shadow(color: resolvedColor.opacity(0.65), radius: severity == .critical ? pulse * 6 : 4)
        }
    }
}

public struct ProviderGlyph: View {
    public let provider: UsageProviderID
    public let size: CGFloat
    public let color: Color

    public init(
        provider: UsageProviderID,
        size: CGFloat,
        color: Color = UsageTheme.secondaryText
    ) {
        self.provider = provider
        self.size = size
        self.color = color
    }

    public var body: some View {
        Image(provider == .claude ? "ClaudeLogo" : "CodexLogo", bundle: providerMarksBundle)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .accessibilityLabel(provider.displayName)
    }

    private var providerMarksBundle: Bundle {
        if let url = Bundle.main.url(
            forResource: "AIUsageKit_AIUsageDesignSystem",
            withExtension: "bundle"
        ), let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }
}

public struct UsagePillButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .allowsTightening(true)
            .foregroundStyle(UsageTheme.primaryText.opacity(configuration.isPressed ? 0.7 : 0.88))
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(
                configuration.isPressed ? Color.white.opacity(0.08) : UsageTheme.buttonFill,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    configuration.isPressed ? Color.white.opacity(0.14) : UsageTheme.buttonBorder,
                    lineWidth: 1
                )
            }
    }
}

private func percentNumber(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(Int(value.rounded()))
}

private func percent(_ value: Double?) -> String {
    guard let value else { return "—" }
    return "\(Int(value.rounded()))%"
}

private func primaryPeriodLabel(
    _ snapshot: ProviderUsageSnapshot,
    language: AppLanguage
) -> String {
    if snapshot.id == .codex,
       snapshot.session.usedPercent == nil,
       snapshot.weekly.usedPercent != nil {
        return language.text("WEEK", "SEMANA")
    }
    return language.text("SESSION", "SESIÓN")
}

private func compactTokens(_ value: Int) -> String {
    switch value {
    case 1_000_000_000...:
        return compactNumber(Double(value) / 1_000_000_000, suffix: "B")
    case 1_000_000...:
        return compactNumber(Double(value) / 1_000_000, suffix: "M")
    case 1_000...:
        return compactNumber(Double(value) / 1_000, suffix: "K")
    default:
        return String(value)
    }
}

private func compactNumber(_ value: Double, suffix: String) -> String {
    let digits = value >= 100 ? 0 : 1
    return value.formatted(
        .number
            .precision(.fractionLength(0...digits))
            .locale(Locale(identifier: "en_US"))
    ) + suffix
}

private func equivalentCost(
    _ totals: WeeklyUsageTotals,
    language: AppLanguage
) -> String {
    guard let cost = totals.equivalentCostUSD else {
        return totals.hasUnpricedModels ? language.text("N/A", "N/D") : "—"
    }
    let formatted = cost.formatted(
        .currency(code: "USD")
            .precision(.fractionLength(cost >= 100 ? 0 : 2))
            .locale(Locale(identifier: "en_US"))
    )
    return "~\(formatted)"
}

func equivalentCostHelp(
    _ totals: WeeklyUsageTotals,
    language: AppLanguage
) -> String {
    if totals.equivalentCostUSD == nil {
        return language.text(
            "No public API rate or model breakdown is available for this period. Tokens and limits still update normally.",
            "No hay tarifa API pública o desglose suficiente para este periodo. Los tokens y límites siguen actualizándose."
        )
    }
    let approvedCopy = language.text(
        "Equivalent cost at API rates for the current weekly period. This is an estimate.",
        "Coste equivalente a tarifas API durante el periodo semanal actual. Estimación."
    )
    if totals.hasUnpricedModels {
        return approvedCopy + " " + language.text(
            "Some usage has no public price or model breakdown and may be omitted.",
            "Parte del uso no tiene tarifa pública o desglose y puede no estar incluida."
        )
    }
    return approvedCopy
}

private func missingLocalHistoryHelp(language: AppLanguage) -> String {
    language.text(
        "Token history is unavailable. Add read-only access in Settings to restore token totals and estimated cost.",
        "El histórico de tokens no está disponible. Añade acceso de solo lectura en Ajustes para recuperar los tokens y el coste estimado."
    )
}

func tokenBreakdown(
    _ totals: WeeklyUsageTotals,
    language: AppLanguage
) -> String {
    var lines = [
        "\(language.text("Weekly total", "Total semanal")): \(compactTokens(totals.totalTokens))",
        "\(language.text("Input", "Entrada")): \(compactTokens(totals.inputTokens))",
        "\(language.text("Cached input", "Entrada en caché")): \(compactTokens(totals.cachedInputTokens))",
        "\(language.text("Cache writes", "Escritura de caché")): \(compactTokens(totals.cacheWriteTokens))",
        "\(language.text("Output", "Salida")): \(compactTokens(totals.outputTokens))",
        "\(language.text("Reasoning (included in output)", "Razonamiento (incluido en salida)")): \(compactTokens(totals.reasoningTokens))"
    ]
    if let unclassified = totals.unclassifiedTokens, unclassified > 0 {
        lines.append("\(language.text("Unclassified", "Sin desglose")): \(compactTokens(unclassified))")
    }
    lines.append("\(language.text("API equivalent", "Equivalente API")): \(equivalentCost(totals, language: language))")
    lines.append(equivalentCostHelp(totals, language: language))
    return lines.joined(separator: "\n")
}

/// Keeps measured endpoint labels within their reserved gutter and separates
/// them vertically. If the available height cannot fit them, omit annotations.
enum UsageTrendLabelLayout {
    static func frames(for targets: [CGRect], in bounds: CGRect, spacing: CGFloat = 4) -> [CGRect] {
        guard !targets.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }
        let requiredHeight = targets.reduce(CGFloat.zero) { $0 + $1.height }
            + CGFloat(targets.count - 1) * spacing
        guard requiredHeight <= bounds.height,
              targets.allSatisfy({ $0.width <= bounds.width }) else { return [] }

        var result = targets.map { target in
            CGRect(x: min(max(target.minX, bounds.minX), bounds.maxX - target.width),
                   y: min(max(target.minY, bounds.minY), bounds.maxY - target.height),
                   width: target.width, height: target.height)
        }
        let order = result.indices.sorted {
            result[$0].minY == result[$1].minY ? $0 < $1 : result[$0].minY < result[$1].minY
        }
        for position in order.indices.dropFirst() {
            let previous = order[position - 1]
            let current = order[position]
            result[current].origin.y = max(result[current].minY, result[previous].maxY + spacing)
        }
        if let last = order.last, result[last].maxY > bounds.maxY {
            result[last].origin.y = bounds.maxY - result[last].height
            for position in order.indices.dropLast().reversed() {
                let current = order[position]
                let next = order[position + 1]
                result[current].origin.y = min(result[current].minY,
                                              result[next].minY - spacing - result[current].height)
            }
        }
        return result
    }
}
