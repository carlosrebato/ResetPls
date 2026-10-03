import AIUsageCore
import AIUsageDesignSystem
import SwiftUI

struct IOSWidgetPreviewGallery: View {
    private var spanishCopies: Bool {
        ProcessInfo.processInfo.arguments.contains("--widget-preview-spanish")
    }

    private var smallProjection: WidgetWeeklyProjection {
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-small-room") { return .roomToSpare }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-small-risk") { return .risk }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-small-high-risk") { return .highRisk }
        return .littleRoomToSpare
    }

    private var mode: PreviewMode {
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-lock-reauth") { return .lockReauth }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-lock-states") { return .lockStates }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-small-copies") { return .smallCopies }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-large-high-risk") { return .largeHighRisk }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-states") { return .states }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-large-risk") { return .largeRisk }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-large-single") { return .largeSingle }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-lock-single") { return .lockSingle }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-lock") { return .lock }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-large") { return .large }
        if ProcessInfo.processInfo.arguments.contains("--widget-preview-home") { return .home }
        return .all
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    previewTitle

                    if mode == .lockReauth {
                        PreviewSection("LOCK · CODEX REAUTH REQUIRED") {
                            VStack(spacing: 10) {
                                RectangularUsageWidgetPreview(
                                    reauthProvider: .codex,
                                    spanishCopies: spanishCopies
                                )
                                InlineUsageWidgetPreview(
                                    reauthProvider: .codex,
                                    spanishCopies: spanishCopies
                                )
                            }
                        }
                    } else if mode == .lockStates {
                        PreviewSection("LOCK · TWO SERVICES · FRESH") {
                            VStack(spacing: 10) {
                                RectangularUsageWidgetPreview(spanishCopies: spanishCopies)
                                InlineUsageWidgetPreview(spanishCopies: spanishCopies)
                            }
                        }
                        PreviewSection("LOCK · ONE SERVICE · FRESH") {
                            VStack(spacing: 10) {
                                RectangularUsageWidgetPreview(providers: [.codex], spanishCopies: spanishCopies)
                                InlineUsageWidgetPreview(providers: [.codex], spanishCopies: spanishCopies)
                            }
                        }
                        PreviewSection("LOCK · PARTIAL UPDATE FAILURE") {
                            VStack(spacing: 10) {
                                RectangularUsageWidgetPreview(state: .staleFailed, spanishCopies: spanishCopies)
                                InlineUsageWidgetPreview(state: .staleFailed, spanishCopies: spanishCopies)
                            }
                        }
                        PreviewSection("LOCK · NO DATA") {
                            VStack(spacing: 10) {
                                RectangularUsageWidgetPreview(
                                    providers: [.codex],
                                    state: .unavailable,
                                    spanishCopies: spanishCopies
                                )
                                InlineUsageWidgetPreview(
                                    providers: [.codex],
                                    state: .unavailable,
                                    spanishCopies: spanishCopies
                                )
                            }
                        }
                    } else if mode == .smallCopies {
                        PreviewSection("SMALL · ROOM TO SPARE") {
                            SmallUsageWidgetPreview(projection: .roomToSpare, spanishCopies: spanishCopies)
                        }
                        PreviewSection("SMALL · LITTLE ROOM") {
                            SmallUsageWidgetPreview(projection: .littleRoomToSpare, spanishCopies: spanishCopies)
                        }
                        PreviewSection("SMALL · RISK") {
                            SmallUsageWidgetPreview(projection: .risk, spanishCopies: spanishCopies)
                        }
                        PreviewSection("SMALL · HIGH RISK") {
                            SmallUsageWidgetPreview(projection: .highRisk, spanishCopies: spanishCopies)
                        }
                    } else if mode == .all || mode == .home {
                        PreviewSection("HOME SCREEN · SMALL") {
                            SmallUsageWidgetPreview(
                                projection: smallProjection,
                                spanishCopies: spanishCopies
                            )
                        }

                        PreviewSection("HOME SCREEN · MEDIUM") {
                            MediumUsageWidgetPreview(spanishCopies: spanishCopies)
                        }

                        if mode == .all {
                            PreviewSection("HOME SCREEN · LARGE") {
                                LargeUsageWidgetPreview(spanishCopies: spanishCopies)
                            }
                        }
                    } else if mode == .large {
                        PreviewSection("HOME SCREEN · LARGE") {
                            LargeUsageWidgetPreview(spanishCopies: spanishCopies)
                        }
                    } else if mode == .largeSingle {
                        PreviewSection("LARGE · ONE SERVICE") {
                            LargeSingleServiceWidgetPreview(spanishCopies: spanishCopies)
                        }
                    } else if mode == .largeRisk {
                        PreviewSection("LARGE · LIMIT RISK") {
                            LargeUsageWidgetPreview(projection: .risk, spanishCopies: spanishCopies)
                        }
                    } else if mode == .largeHighRisk {
                        PreviewSection("LARGE · HIGH LIMIT RISK") {
                            LargeUsageWidgetPreview(projection: .highRisk, spanishCopies: spanishCopies)
                        }
                    } else if mode == .lockSingle {
                        PreviewSection("LOCK SCREEN · ONE SERVICE") {
                            RectangularUsageWidgetPreview(providers: [.codex])
                        }

                        PreviewSection("INLINE · ONE SERVICE") {
                            InlineUsageWidgetPreview(providers: [.codex])
                        }
                    } else if mode == .states {
                        PreviewSection("SMALL · UPDATE FAILED") {
                            SmallUsageWidgetPreview(state: .staleFailed, spanishCopies: spanishCopies)
                        }

                        PreviewSection("SMALL · NO DATA") {
                            SmallUsageWidgetPreview(state: .unavailable, spanishCopies: spanishCopies)
                        }

                        PreviewSection("MEDIUM · PARTIAL FAILURE") {
                            MediumUsageWidgetPreview(codexState: .staleFailed, spanishCopies: spanishCopies)
                        }
                    } else {
                        PreviewSection("LOCK SCREEN · RECTANGULAR") {
                            RectangularUsageWidgetPreview()
                        }

                        PreviewSection("LOCK SCREEN · INLINE") {
                            InlineUsageWidgetPreview()
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private var previewTitle: some View {
        VStack(spacing: 6) {
            Text("RESETPLS · WIDGETS")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(UsageTheme.secondaryText)
            Text("Native widget states")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UsageTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum PreviewMode {
    case all
    case lockReauth
    case lockStates
    case smallCopies
    case home
    case large
    case largeSingle
    case largeRisk
    case largeHighRisk
    case lock
    case lockSingle
    case states
}

private enum WidgetDataState {
    case fresh
    case staleFailed
    case unavailable
}

private enum WidgetWeeklyProjection {
    case roomToSpare
    case littleRoomToSpare
    case risk
    case highRisk

    var english: String {
        switch self {
        case .roomToSpare: "Weekly limit: room to spare"
        case .littleRoomToSpare: "Weekly limit: little room to spare"
        case .risk: "Risk of reaching the weekly limit"
        case .highRisk: "High risk of reaching the weekly limit"
        }
    }

    var spanish: String {
        switch self {
        case .roomToSpare: "Límite semanal: con margen"
        case .littleRoomToSpare: "Límite semanal: vas justo"
        case .risk: "Riesgo de alcanzar el límite semanal"
        case .highRisk: "Riesgo alto de alcanzar el límite semanal"
        }
    }

    var color: Color {
        switch self {
        case .roomToSpare, .littleRoomToSpare: UsageTheme.mutedText
        case .risk: UsageTheme.amber
        case .highRisk: UsageTheme.red
        }
    }

    var severity: UsageSeverity {
        // Projection changes the explanatory copy, not the provider's meter.
        // This keeps warning semantics legible without turning the whole card
        // into a traffic-light display.
        .normal
    }

    func text(spanish: Bool) -> String {
        spanish ? self.spanish : english
    }
}

private struct PreviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.45)
                .foregroundStyle(UsageTheme.mutedText)
            content
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SmallUsageWidgetPreview: View {
    var state: WidgetDataState = .fresh
    var projection: WidgetWeeklyProjection = .littleRoomToSpare
    var spanishCopies = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    ProviderGlyph(provider: .codex, size: 13, color: UsageTheme.secondaryText)
                    Text("CODEX")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(UsageTheme.secondaryText)
                }
                Spacer()
                freshness
            }

            gauge
                .padding(.top, 9)
                .padding(.bottom, 14)

            switch state {
            case .fresh:
                Text(projection.text(spanish: spanishCopies))
                    .foregroundStyle(projection.color)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            case .staleFailed:
                Text("UPDATE FAILED · OPEN APP")
                    .tracking(0.7)
                    .foregroundStyle(UsageTheme.cached)
            case .unavailable:
                Text("OPEN APP TO CONNECT")
                    .tracking(0.7)
                    .foregroundStyle(UsageTheme.red)
            }
        }
        .font(.system(size: 7.5, weight: .semibold))
        .foregroundStyle(UsageTheme.mutedText)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(width: 170, height: 170)
        .widgetPreviewPanel()
        .frame(maxWidth: .infinity)
    }

    private var freshness: some View {
        HStack(spacing: 4) {
            Image(systemName: state == .fresh ? "circle.fill" : "clock.fill")
                .font(.system(size: state == .fresh ? 5 : 7, weight: .bold))
            Text(state == .fresh ? "12:17" : state == .staleFailed ? "10:14" : "—")
                .font(.system(size: 7.5, weight: .bold))
                .tracking(0.7)
        }
        .foregroundStyle(freshnessColor)
    }

    private var freshnessColor: Color {
        switch state {
        case .fresh: UsageTheme.green.opacity(0.9)
        case .staleFailed: UsageTheme.cached
        case .unavailable: UsageTheme.red
        }
    }

    private var gauge: some View {
        ZStack {
            Circle().stroke(UsageTheme.track, lineWidth: 8)
            if state != .unavailable {
                Circle()
                    .trim(from: 0, to: 0.64)
                    .stroke(
                        UsageTheme.codex.opacity(state == .fresh ? 1 : 0.52),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                Text(state == .unavailable ? "—" : "64%")
                    .font(.system(size: 25, weight: .bold))
                    .tracking(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(UsageTheme.primaryText)
                Text(state == .unavailable ? "UNAVAILABLE" : "WEEK")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(state == .unavailable ? UsageTheme.red : UsageTheme.mutedText)
                if state == .fresh {
                    Text("RESET 5d")
                        .font(.system(size: 6.5, weight: .semibold, design: .monospaced))
                        .tracking(0.45)
                        .foregroundStyle(UsageTheme.mutedText.opacity(0.85))
                }
            }
        }
        .frame(width: 88, height: 88)
    }
}

private struct MediumUsageWidgetPreview: View {
    var codexState: WidgetDataState = .fresh
    var spanishCopies = false

    var body: some View {
        HStack(spacing: 0) {
            compactProvider(
                .claude,
                primary: 28,
                period: "SESSION",
                secondaryWeekly: 43,
                reset: "1h 42m",
                projection: .roomToSpare,
                state: .fresh
            )
            Rectangle()
                .fill(UsageTheme.hairline)
                .frame(width: 1)
                .padding(.vertical, 2)
            compactProvider(
                .codex,
                primary: 64,
                period: "WEEK",
                secondaryWeekly: nil,
                reset: "5d",
                projection: .littleRoomToSpare,
                state: codexState
            )
        }
        .padding(14)
        .frame(width: 364, height: 170)
        .widgetPreviewPanel()
        .frame(maxWidth: .infinity)
    }

    private func compactProvider(
        _ provider: UsageProviderID,
        primary: Double,
        period: String,
        secondaryWeekly: Double?,
        reset: String,
        projection: WidgetWeeklyProjection,
        state: WidgetDataState
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                ProviderGlyph(provider: provider, size: 13, color: UsageTheme.secondaryText)
                Text(provider == .claude ? "Claude Code" : "Codex")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(UsageTheme.secondaryText)
                Spacer()
                if state == .staleFailed {
                    Label("10:14", systemImage: "clock.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(UsageTheme.cached)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(primary))")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-1)
                Text("%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(UsageTheme.tertiaryText)
                Text(period)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(UsageTheme.mutedText)
                Spacer()
            }
            .foregroundStyle(UsageTheme.primaryText)

            UsageMeter(value: primary, severity: .normal, height: 5)
                .opacity(state == .staleFailed ? 0.5 : 1)

            HStack(spacing: 5) {
                Text("RESETS")
                    .tracking(1)
                Text(reset)
                    .monospacedDigit()
                Spacer()
                if let secondaryWeekly {
                    Text("WK \(Int(secondaryWeekly))%")
                }
            }
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(UsageTheme.mutedText)

            Text(
                state == .staleFailed
                    ? "UPDATE FAILED · OPEN APP"
                    : projection.text(spanish: spanishCopies)
            )
                .font(.system(size: 7.5, weight: .bold))
                .tracking(0.35)
                .foregroundStyle(
                    state == .staleFailed
                        ? UsageTheme.cached
                        : projection.color
                )
                .lineLimit(2)
        }
        .opacity(state == .staleFailed ? 0.82 : 1)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LargeUsageWidgetPreview: View {
    var projection: WidgetWeeklyProjection = .littleRoomToSpare
    var spanishCopies = false

    private var codexPercent: Double {
        switch projection {
        case .roomToSpare, .littleRoomToSpare: 64
        case .risk: 78
        case .highRisk: 88
        }
    }

    private var isRisk: Bool {
        projection == .risk || projection == .highRisk
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            providerRow(
                .claude,
                primary: 28,
                period: "SESSION",
                secondaryWeekly: 43,
                reset: "1h 42m",
                projection: .roomToSpare
            )
                .padding(.top, 12)
            divider
            providerRow(
                .codex,
                primary: codexPercent,
                period: "WEEK",
                secondaryWeekly: nil,
                reset: "5d",
                projection: projection
            )
            divider

            HStack {
                Text("QUOTA · LAST 7 DAYS")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(UsageTheme.mutedText)
                Spacer()
                legend
            }
            .padding(.top, 11)

            WidgetPreviewChart(offTrack: isRisk, highRisk: projection == .highRisk)
                .frame(height: 92)
                .padding(.top, 5)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("7")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(UsageTheme.green)
                        Text("DAY STREAK")
                            .font(.system(size: 8.5, weight: .bold))
                            .tracking(1.3)
                            .foregroundStyle(UsageTheme.green.opacity(0.72))
                    }
                    streakDots
                }
                Spacer()
                Text("UPDATED 12:14")
                    .font(.system(size: 7.5, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(UsageTheme.mutedText)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 364, height: 382)
        .widgetPreviewPanel()
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("RESETPLS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.55)
                .foregroundStyle(UsageTheme.mutedText)
            Spacer()
            Text("12:17")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(UsageTheme.primaryText)
        }
    }

    private func providerRow(
        _ provider: UsageProviderID,
        primary: Double,
        period: String,
        secondaryWeekly: Double?,
        reset: String,
        projection: WidgetWeeklyProjection
    ) -> some View {
        VStack(spacing: 7) {
            HStack {
                ProviderGlyph(provider: provider, size: 13, color: UsageTheme.secondaryText)
                Text(provider == .claude ? "Claude Code" : "Codex")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UsageTheme.primaryText)
                Spacer()
                Text("\(Int(primary))%")
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(UsageTheme.primaryText)
                Text(period)
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(UsageTheme.mutedText)
            }

            UsageMeter(value: primary, severity: projection.severity, height: 5)

            HStack {
                Text("RESETS \(reset)")
                Spacer()
                if let secondaryWeekly {
                    Text("WEEK \(Int(secondaryWeekly))%")
                }
                Text("· \(projection.text(spanish: spanishCopies))")
                    .foregroundStyle(projection.color)
            }
            .font(.system(size: 7.5, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(UsageTheme.mutedText)
        }
        .padding(.vertical, 9)
    }

    private var divider: some View {
        Rectangle().fill(UsageTheme.hairline).frame(height: 1)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Label("Claude", systemImage: "circle.fill")
                .foregroundStyle(UsageTheme.claude)
            Label("Codex", systemImage: "circle.fill")
                .foregroundStyle(UsageTheme.codex)
        }
        .font(.system(size: 7.5, weight: .semibold))
        .labelStyle(WidgetLegendLabelStyle())
    }

    private var streakDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(streakColor(Double(index) / 6))
                    .frame(width: index == 6 ? 7 : 6, height: index == 6 ? 7 : 6)
                    .shadow(color: index == 6 ? UsageTheme.green.opacity(0.75) : .clear, radius: 6)
            }
        }
    }

    private func streakColor(_ progress: Double) -> Color {
        Color(
            red: (18 + (62 - 18) * progress) / 255,
            green: (59 + (207 - 59) * progress) / 255,
            blue: (48 + (142 - 48) * progress) / 255
        )
    }
}

private struct LargeSingleServiceWidgetPreview: View {
    var spanishCopies = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("RESETPLS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.55)
                    .foregroundStyle(UsageTheme.mutedText)
                Spacer()
                Text("12:17")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(UsageTheme.primaryText)
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        ProviderGlyph(provider: .codex, size: 15, color: UsageTheme.secondaryText)
                        Text("Codex")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(UsageTheme.primaryText)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("64")
                            .font(.system(size: 44, weight: .bold))
                            .tracking(-1.4)
                        Text("%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(UsageTheme.tertiaryText)
                        Text("WEEK")
                            .font(.system(size: 8.5, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(UsageTheme.mutedText)
                    }
                    .foregroundStyle(UsageTheme.primaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("RESETS IN")
                        .font(.system(size: 7.5, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(UsageTheme.mutedText)
                    Text("5d")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(UsageTheme.secondaryText)
                }
            }
            .padding(.top, 18)

            UsageMeter(value: 64, severity: .normal, height: 6)
                .padding(.top, 10)

            HStack {
                Text(WidgetWeeklyProjection.littleRoomToSpare.text(spanish: spanishCopies))
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(WidgetWeeklyProjection.littleRoomToSpare.color)
                Spacer()
            }
            .padding(.top, 8)

            Rectangle().fill(UsageTheme.hairline).frame(height: 1)
                .padding(.top, 13)

            HStack {
                Text("QUOTA · LAST 7 DAYS")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(UsageTheme.mutedText)
                Spacer()
                Label("Codex", systemImage: "circle.fill")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(UsageTheme.codex)
                    .labelStyle(WidgetLegendLabelStyle())
            }
            .padding(.top, 12)

            WidgetPreviewChart(providers: [.codex])
                .frame(height: 120)
                .padding(.top, 4)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("7")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(UsageTheme.green)
                        Text("DAY STREAK")
                            .font(.system(size: 8.5, weight: .bold))
                            .tracking(1.3)
                            .foregroundStyle(UsageTheme.green.opacity(0.72))
                    }
                    HStack(spacing: 5) {
                        ForEach(0..<7, id: \.self) { index in
                            Circle()
                                .fill(singleStreakColor(Double(index) / 6))
                                .frame(width: index == 6 ? 7 : 6, height: index == 6 ? 7 : 6)
                        }
                    }
                }
                Spacer()
                Text("UPDATED 12:14")
                    .font(.system(size: 7.5, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(UsageTheme.mutedText)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 364, height: 382)
        .widgetPreviewPanel()
        .frame(maxWidth: .infinity)
    }

    private func singleStreakColor(_ progress: Double) -> Color {
        Color(
            red: (18 + (62 - 18) * progress) / 255,
            green: (59 + (207 - 59) * progress) / 255,
            blue: (48 + (142 - 48) * progress) / 255
        )
    }
}

private struct WidgetPreviewChart: View {
    var providers: Set<UsageProviderID> = Set(UsageProviderID.allCases)
    var offTrack = false
    var highRisk = false

    private let claude: [CGFloat] = [22, 31, 19, 46, 38, 51, 43]
    private var codex: [CGFloat] {
        if highRisk { return [35, 42, 50, 59, 69, 79, 88] }
        return offTrack ? [35, 39, 46, 52, 61, 70, 78] : [35, 28, 44, 32, 57, 49, 64]
    }

    var body: some View {
        Canvas { context, size in
            let top: CGFloat = 12
            let baseline = size.height - 18
            let plotHeight = baseline - top

            for fraction in [CGFloat(0), 0.5] {
                var grid = Path()
                let y = top + plotHeight * fraction
                grid.move(to: CGPoint(x: 2, y: y))
                grid.addLine(to: CGPoint(x: size.width - 2, y: y))
                context.stroke(grid, with: .color(Color.white.opacity(0.09)), style: StrokeStyle(lineWidth: 1, dash: [2, 7]))
            }
            if providers.contains(.claude) {
                drawLine(claude, color: UsageTheme.claude, top: top, baseline: baseline, context: &context)
            }
            if providers.contains(.codex) {
                drawLine(
                    codex,
                    color: UsageTheme.codex,
                    top: top,
                    baseline: baseline,
                    context: &context
                )
            }

            let labels = ["S", "M", "T", "W", "T", "F", "S"]
            for index in labels.indices {
                let x = 3 + (size.width - 6) * CGFloat(index) / CGFloat(labels.count - 1)
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 1.5, y: baseline - 1.5, width: 3, height: 3)),
                    with: .color(Color.white.opacity(0.2))
                )
                context.draw(
                    Text(labels[index])
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(UsageTheme.mutedText),
                    at: CGPoint(x: x, y: size.height - 5),
                    anchor: .center
                )
            }
        }
    }

    private func drawLine(
        _ values: [CGFloat],
        color: Color,
        top: CGFloat,
        baseline: CGFloat,
        context: inout GraphicsContext
    ) {
        let size = context.clipBoundingRect.size
        let points = values.enumerated().map { index, value in
            CGPoint(
                x: 3 + (size.width - 6) * CGFloat(index) / CGFloat(values.count - 1),
                y: baseline - (baseline - top) * value / 100
            )
        }
        let path = smoothPath(points)
        guard let first = points.first, let last = points.last else { return }

        var area = path
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
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round))

        for (index, point) in points.enumerated() {
            let isToday = index == points.count - 1
            if isToday {
                context.stroke(
                    Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)),
                    with: .color(color.opacity(0.34)),
                    lineWidth: 1.5
                )
            }
            let radius: CGFloat = isToday ? 3.2 : 2
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color)
            )
        }
    }

    private func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        for index in 0..<(points.count - 1) {
            let previous = index > 0 ? points[index - 1] : points[index]
            let current = points[index]
            let next = points[index + 1]
            let following = index + 2 < points.count ? points[index + 2] : next
            let control1 = CGPoint(
                x: current.x + (next.x - previous.x) / 6,
                y: current.y + (next.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: next.x - (following.x - current.x) / 6,
                y: next.y - (following.y - current.y) / 6
            )
            path.addCurve(to: next, control1: control1, control2: control2)
        }
        return path
    }
}

private struct RectangularUsageWidgetPreview: View {
    var providers: Set<UsageProviderID> = Set(UsageProviderID.allCases)
    var state: WidgetDataState = .fresh
    var reauthProvider: UsageProviderID?
    var spanishCopies = false

    var body: some View {
        Group {
            if state == .unavailable {
                unavailableService
            } else if providers.count == 1 {
                singleService
            } else {
                VStack(spacing: 7) {
                    metric(
                        .claude,
                        percent: 28,
                        reset: "1h 42m",
                        state: .fresh,
                        requiresReauth: reauthProvider == .claude
                    )
                    metric(
                        .codex,
                        percent: 64,
                        reset: "5d",
                        state: state,
                        requiresReauth: reauthProvider == .codex
                    )
                }
                .padding(.horizontal, 13)
            }
        }
        .frame(width: 348, height: 74)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
    }

    private var singleService: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProviderGlyph(provider: .codex, size: 13, color: .white.opacity(0.82))
                Text("Codex")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("64%")
                    .font(.system(size: 19, weight: .bold))
                    .monospacedDigit()
                Text(spanishCopies ? "SEMANA" : "WEEK")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.58))
            }
            HStack(spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.13))
                        Capsule().fill(.white.opacity(0.8)).frame(width: proxy.size.width * 0.64)
                    }
                }
                .frame(height: 5)
                Text(spanishCopies ? "REINICIA 5d" : "RESETS 5d")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
    }

    private var unavailableService: some View {
        HStack(spacing: 10) {
            ProviderGlyph(provider: .codex, size: 13, color: .white.opacity(0.72))
            VStack(alignment: .leading, spacing: 3) {
                Text("Codex")
                    .font(.system(size: 12, weight: .semibold))
                Text(spanishCopies ? "ABRE LA APP PARA CONECTAR" : "OPEN APP TO CONNECT")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.55)
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Text("—")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
    }

    private func metric(
        _ provider: UsageProviderID,
        percent: Int,
        reset: String,
        state: WidgetDataState,
        requiresReauth: Bool
    ) -> some View {
        HStack(spacing: 8) {
            ProviderGlyph(provider: provider, size: 11, color: .white.opacity(0.82))
            Text("\(percent)%")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(requiresReauth ? 0.58 : 1))
                .frame(width: 31, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.13))
                    Capsule()
                        .fill(.white.opacity(state == .fresh && !requiresReauth ? 0.78 : 0.42))
                        .frame(width: proxy.size.width * CGFloat(percent) / 100)
                }
            }
            .frame(height: 4)
            if requiresReauth {
                Text(spanishCopies ? "RECONECTA" : "RECONNECT")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(0.35)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 62, alignment: .trailing)
            } else if state == .staleFailed {
                Label("10:14", systemImage: "clock.fill")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(width: 52, alignment: .trailing)
            } else {
                Text(reset)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

private struct InlineUsageWidgetPreview: View {
    var providers: Set<UsageProviderID> = Set(UsageProviderID.allCases)
    var state: WidgetDataState = .fresh
    var reauthProvider: UsageProviderID?
    var spanishCopies = false

    var body: some View {
        HStack(spacing: 7) {
            if state == .unavailable {
                ProviderGlyph(provider: .codex, size: 11, color: .white.opacity(0.72))
                Text(spanishCopies ? "Abrir app para reconectar" : "Open app to reconnect")
            } else if providers.contains(.claude) {
                ProviderGlyph(provider: .claude, size: 11, color: .white.opacity(0.82))
                Text("28%")
                if providers.count > 1 {
                    Text("·").foregroundStyle(.white.opacity(0.42))
                }
                if providers.contains(.codex) {
                    ProviderGlyph(provider: .codex, size: 11, color: .white.opacity(0.82))
                    Text(reauthProvider == .codex
                        ? (spanishCopies ? "Reconecta" : "Reconnect")
                        : "64%"
                    )
                }
                if reauthProvider == nil {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(state == .staleFailed ? "10:14" : providers.count == 1 ? "5d" : "1h 29m")
                }
            } else if providers.contains(.codex) {
                ProviderGlyph(provider: .codex, size: 11, color: .white.opacity(0.82))
                if reauthProvider == .codex {
                    Text(spanishCopies ? "Reconecta" : "Reconnect")
                } else {
                    Text("64%")
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(state == .staleFailed ? "10:14" : "5d")
                }
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .frame(height: 34)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1) }
        .frame(maxWidth: .infinity)
    }
}

private struct WidgetLegendLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 5))
            configuration.title.foregroundStyle(UsageTheme.mutedText)
        }
    }
}

private extension View {
    func widgetPreviewPanel() -> some View {
        background(UsageTheme.panelGradient)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            }
    }
}
