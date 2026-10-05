import Foundation

public enum UsageQuotaID: Equatable, Sendable {
    case session
    case weekly
}

public enum PaceEstimate: Equatable, Sendable {
    case insufficientData
    case onTrackToReset
    case limitIn(TimeInterval, quota: UsageQuotaID? = nil)
}

public enum SessionPaceStatus: Equatable, Sendable {
    case noUsage
    case newSession
    case measuring
    case unavailable
    case onTrack
    case limitIn(TimeInterval)
}

public enum UsageAvailability: Equatable, Sendable {
    case available
    case blocked(until: Date?)
}

public enum WeeklyRiskState: Equatable, Sendable {
    case roomToSpare
    case onTrack
    case atRisk
    case highRisk
}

/// One provider-level status for dots in every surface. Freshness is separate
/// from quota severity: a saved value never claims a live risk assessment.
public enum ProviderSignal: Equatable, Sendable {
    case normal
    case warning
    case critical
    case cached
    case unavailable
}

/// A conditional comparison with an even pace across the verified weekly window.
/// The projected percentage is not a probability or a forecast of future activity.
public struct WeeklyRiskAssessment: Equatable, Sendable {
    public let state: WeeklyRiskState
    public let usedPercent: Double
    public let elapsedPercent: Double
    public let projectedPercent: Double
}

/// Per-provider quota samples, carried by the existing last-known snapshot cache.
/// No credentials, extra polling, database, or additional disk writes are needed.
public struct UsagePaceHistory: Equatable, Codable, Sendable {
    public struct Sample: Equatable, Codable, Sendable {
        public let timestamp: Date
        public let percent: Double
        public let reset: Date
    }

    public private(set) var session: [Sample] = []
    public private(set) var weekly: [Sample] = []

    public init() {}

    public mutating func record(_ snapshot: ProviderUsageSnapshot) {
        guard snapshot.source == .live else { return }
        Self.record(snapshot.session, at: snapshot.observedAt, into: &session)
        Self.record(snapshot.weekly, at: snapshot.observedAt, into: &weekly)
    }

    private static func record(_ window: UsageWindow, at date: Date, into samples: inout [Sample]) {
        guard let percent = window.usedPercent, percent.isFinite, (0...100).contains(percent),
              let reset = window.resetsAt, reset.timeIntervalSince1970.isFinite,
              date.timeIntervalSince1970.isFinite, reset > date else { return }
        if let last = samples.last {
            guard date > last.timestamp else { return }
            // A decrease also starts a new series when the provider keeps the same reset date.
            if last.reset != reset || percent < last.percent {
                samples.removeAll()
            } else if date.timeIntervalSince(last.timestamp) < 30 {
                return
            }
        }
        samples.removeAll { date.timeIntervalSince($0.timestamp) > 3_600 }
        samples.append(Sample(timestamp: date, percent: percent, reset: reset))
        samples = Array(samples.suffix(121))
    }

    public static func estimate(
        window: UsageWindow, samples: [Sample], now: Date
    ) -> PaceEstimate {
        guard !window.isExhausted,
              let percent = window.usedPercent, percent.isFinite, (0..<100).contains(percent),
              let reset = window.resetsAt, reset > now else { return .insufficientData }
        let recent = samples.filter {
            $0.percent.isFinite && (0...100).contains($0.percent)
                && $0.reset == reset && $0.timestamp <= now
                && now.timeIntervalSince($0.timestamp) <= 3_600
        }
        guard recent.count >= 3, let first = recent.first, let last = recent.last,
              now.timeIntervalSince(last.timestamp) <= 600,
              last.percent == percent,
              last.timestamp.timeIntervalSince(first.timestamp) >= 600 else {
            return .insufficientData
        }
        let pairs = zip(recent, recent.dropFirst())
        guard pairs.allSatisfy({ $1.timestamp > $0.timestamp && $1.percent >= $0.percent }) else {
            return .insufficientData
        }
        let change = last.percent - first.percent
        if change <= 0.01 { return .onTrackToReset }
        // One isolated provider jump is not enough evidence of sustained consumption.
        guard change >= 1,
              pairs.filter({ $1.percent > $0.percent }).count >= 2 else {
            return .insufficientData
        }
        let count = Double(recent.count)
        let times = recent.map { $0.timestamp.timeIntervalSince(first.timestamp) }
        let meanTime = times.reduce(0, +) / count
        let meanPercent = recent.map(\.percent).reduce(0, +) / count
        let variance = times.reduce(0) { $0 + pow($1 - meanTime, 2) }
        let covariance = zip(times, recent).reduce(0) {
            $0 + ($1.0 - meanTime) * ($1.1.percent - meanPercent)
        }
        let rate = max(0, covariance / variance)
        guard rate.isFinite, rate > 0.000_001 else { return .onTrackToReset }
        let duration = (100 - percent) / rate
        guard duration.isFinite, duration > 0 else { return .insufficientData }
        return duration < reset.timeIntervalSince(now) ? .limitIn(duration) : .onTrackToReset
    }

    /// A decisive session-wide average can still identify an early limit when
    /// sparse polling or a single large jump prevents the rolling fit. It is
    /// deliberately one-sided: weak evidence never claims the session is safe.
    public static func decisiveSessionFallback(window: UsageWindow, now: Date) -> PaceEstimate? {
        guard let percent = window.usedPercent, percent.isFinite, (20..<100).contains(percent),
              let reset = window.resetsAt, reset > now,
              let duration = window.durationSeconds, duration.isFinite, duration > 0 else {
            return nil
        }
        let elapsed = now.timeIntervalSince(reset.addingTimeInterval(-duration))
        guard elapsed.isFinite, elapsed > 0, elapsed < duration else { return nil }

        let minimumElapsed = min(15 * 60, duration * 0.1)
        guard elapsed >= minimumElapsed || percent >= 70 else { return nil }
        let effectiveElapsed = max(elapsed, minimumElapsed)
        let eta = effectiveElapsed * (100 - percent) / percent
        let remaining = reset.timeIntervalSince(now)
        guard eta.isFinite, eta > 0, eta < remaining * 0.8 else { return nil }
        return .limitIn(eta)
    }
}

extension ProviderUsageSnapshot {
    public func signal(at now: Date) -> ProviderSignal {
        guard highestPercent != nil, source != .unavailable else { return .unavailable }
        if source == .cached || isStale(at: now) { return .cached }
        if source == .mock { return .normal }
        if availability != .available { return .critical }
        let percentSeverity = UsageSeverity.forPercent(highestPercent)
        if percentSeverity == .critical || weeklyRisk(at: now)?.state == .highRisk {
            return .critical
        }
        if percentSeverity == .warning || weeklyRisk(at: now)?.state == .atRisk {
            return .warning
        }
        // A weekly-only provider must not turn amber because of a short burst
        // in the rolling pace estimator while its weekly assessment is safe.
        if case .limitIn = sessionPaceEstimate(at: now) { return .warning }
        return .normal
    }

    /// Only evaluate a verified, current weekly-only primary quota. A short burst
    /// of activity must not be extrapolated into an all-week risk score.
    public func weeklyRisk(at now: Date) -> WeeklyRiskAssessment? {
        guard primaryDisplayWindow == weekly, source == .live, !isStale(at: now),
              weekly.isVerifiedWeekly,
              let used = weekly.usedPercent, used.isFinite, (0..<100).contains(used),
              let reset = weekly.resetsAt, reset > now,
              let duration = weekly.durationSeconds else { return nil }
        let start = reset.addingTimeInterval(-duration)
        let elapsed = now.timeIntervalSince(start)
        guard elapsed >= 0, elapsed < duration else { return nil }

        // Weekly usage has a human day/night cadence. During day one, compare
        // against at least one day's share of the week instead of extending a
        // few active hours around the clock. This still gives an estimate from
        // the reset instant, catches substantial first-day usage, and joins the
        // ordinary elapsed-time projection continuously at 24 hours.
        let projectionElapsed = max(elapsed, 24 * 60 * 60)
        let projected = used / (projectionElapsed / duration)
        guard projected.isFinite else { return nil }
        let state: WeeklyRiskState
        if projected < 80 {
            state = .roomToSpare
        } else if projected <= 105 {
            state = .onTrack
        } else if projected <= 125 {
            state = .atRisk
        } else if elapsed >= 48 * 60 * 60, hasConfirmedWeeklyReadings(reset: reset, used: used) {
            state = .highRisk
        } else {
            state = .atRisk
        }
        return WeeklyRiskAssessment(
            state: state, usedPercent: used,
            elapsedPercent: elapsed / duration * 100,
            projectedPercent: projected
        )
    }

    private func hasConfirmedWeeklyReadings(reset: Date, used: Double) -> Bool {
        guard let samples = paceHistory?.weekly else { return false }
        let recent = samples.filter {
            $0.reset == reset && $0.timestamp <= observedAt
                && observedAt.timeIntervalSince($0.timestamp) <= 3_600
        }
        guard recent.count >= 2, let first = recent.first, let last = recent.last,
              observedAt.timeIntervalSince(first.timestamp) >= 30 * 60,
              last.percent == used else { return false }
        return zip(recent, recent.dropFirst()).allSatisfy {
            $0.timestamp < $1.timestamp && $0.percent <= $1.percent
        }
    }

    public var availability: UsageAvailability {
        let blocking = [session, weekly].filter(\.isExhausted)
        guard !blocking.isEmpty else { return .available }
        // An unknown blocking reset must not promise availability at another quota's reset.
        guard blocking.allSatisfy({ $0.resetsAt != nil }) else { return .blocked(until: nil) }
        return .blocked(until: blocking.compactMap(\.resetsAt).max())
    }

    public var availabilityReset: Date? {
        switch availability {
        case .available: primaryDisplayWindow.resetsAt
        case .blocked(let reset): reset
        }
    }

    public var displaysWeeklyReset: Bool {
        availability == .available && primaryDisplayWindow == weekly
            && weekly.isVerifiedWeekly && weekly.resetsAt != nil
    }

    /// nil means Pace is suppressed (blocked, cached, unavailable, or stale).
    public func paceEstimate(at now: Date) -> PaceEstimate? {
        guard availability == .available, source == .live, !isStale(at: now) else { return nil }
        let history = paceHistory ?? UsagePaceHistory()
        let windows: [(UsageQuotaID, UsageWindow, [UsagePaceHistory.Sample])] = [
            (.session, session, history.session), (.weekly, weekly, history.weekly)
        ]
        let estimates = windows.filter { $0.1.usedPercent != nil }.map { quota, window, samples in
            let estimate = UsagePaceHistory.estimate(window: window, samples: samples, now: now)
            if case .limitIn(let duration, _) = estimate {
                return PaceEstimate.limitIn(duration, quota: quota)
            }
            return estimate
        }
        let predicted = estimates.compactMap { estimate -> (TimeInterval, PaceEstimate)? in
            if case .limitIn(let duration, _) = estimate { return (duration, estimate) }
            return nil
        }
        if let first = predicted.min(by: { $0.0 < $1.0 }) { return first.1 }
        return !estimates.isEmpty && estimates.allSatisfy { $0 == .onTrackToReset }
            ? .onTrackToReset : .insufficientData
    }

    /// Presentation for services that expose a five-hour session. The global
    /// signal still considers both quotas, but session copy must describe the
    /// session rather than unexpectedly switching to the weekly window.
    public func sessionPaceEstimate(at now: Date) -> PaceEstimate? {
        guard availability == .available, source == .live, !isStale(at: now),
              session.usedPercent != nil else { return nil }
        let estimate = UsagePaceHistory.estimate(
            window: session, samples: paceHistory?.session ?? [], now: now
        )
        if case .limitIn(let duration, _) = estimate {
            return .limitIn(duration, quota: .session)
        }
        if estimate == .insufficientData,
           case .limitIn(let duration, _)? = UsagePaceHistory.decisiveSessionFallback(
               window: session, now: now
           ) {
            return .limitIn(duration, quota: .session)
        }
        return estimate
    }

    public func sessionPaceStatus(at now: Date) -> SessionPaceStatus? {
        guard let percent = session.usedPercent, percent.isFinite,
              (0...100).contains(percent), availability == .available else { return nil }
        if source == .mock { return .measuring }
        guard source == .live, !isStale(at: now) else { return .unavailable }
        // Percentages are displayed as whole numbers, so use the same boundary.
        if percent < 0.5 { return .noUsage }
        guard let reset = session.resetsAt, reset > now else { return .unavailable }

        switch sessionPaceEstimate(at: now) {
        case .limitIn(let duration, _): return .limitIn(duration)
        case .onTrackToReset: return .onTrack
        case .insufficientData:
            if let duration = session.durationSeconds, duration.isFinite, duration > 0,
               (0..<15 * 60).contains(now.timeIntervalSince(
                   reset.addingTimeInterval(-duration)
               )) {
                return .newSession
            }
            return .measuring
        case nil: return .unavailable
        }
    }

    public func recordingPace(previous: ProviderUsageSnapshot?) -> ProviderUsageSnapshot {
        var history = (previous?.id == id ? previous?.paceHistory : nil) ?? UsagePaceHistory()
        history.record(self)
        return ProviderUsageSnapshot(
            id: id, session: session, weekly: weekly, observedAt: observedAt,
            source: source, message: message, weeklyTotals: weeklyTotals, paceHistory: history
        )
    }
}

public enum UsagePaceFormatter {
    public static func string(duration: TimeInterval) -> String {
        guard duration.isFinite, duration > 0 else { return "~1m" }
        let step: Double = duration < 3_600 ? 120 : duration < 6 * 3_600 ? 600
            : duration < 24 * 3_600 ? 3_600 : 6 * 3_600
        let rounded = max(60, (duration / step).rounded() * step)
        return "~" + UsageResetFormatter.string(
            until: Date(timeIntervalSince1970: rounded), relativeTo: Date(timeIntervalSince1970: 0)
        ).replacingOccurrences(of: " 0m", with: "")
    }
}

extension AppLanguage {
    public func weeklyRiskText(_ assessment: WeeklyRiskAssessment) -> String {
        switch assessment.state {
        case .roomToSpare:
            text(
                "At this pace, you should stay comfortably within your weekly limit",
                "A este ritmo, llegarías al reinicio semanal con margen"
            )
        case .onTrack:
            text(
                "At this pace, you could come close to your weekly limit",
                "A este ritmo, podrías acercarte al límite semanal"
            )
        case .atRisk: text("Risk of reaching the weekly limit", "Riesgo de alcanzar el límite semanal")
        case .highRisk: text("High risk of reaching the weekly limit", "Riesgo alto de alcanzar el límite semanal")
        }
    }

    public func weeklyRiskHelp(_ assessment: WeeklyRiskAssessment) -> String {
        let used = Int(assessment.usedPercent.rounded())
        if assessment.elapsedPercent < 100.0 / 7.0 {
            return text(
                "You've used \(used)% of your weekly limit. This early estimate may change as you use the service.",
                "Has usado el \(used) % de tu límite semanal. Esta estimación inicial puede cambiar según tu uso."
            )
        }
        let elapsed = assessment.elapsedPercent < 0.5
            ? text("less than 1%", "menos del 1 %")
            : text("\(Int(assessment.elapsedPercent.rounded()))%", "el \(Int(assessment.elapsedPercent.rounded())) %")
        let opening = text(
            "You've used \(used)% of your weekly limit, and \(elapsed) of the period has elapsed.",
            "Has usado el \(used) % del límite semanal y ha transcurrido \(elapsed) del periodo."
        )
        return opening + " " + text(
            "We compare the two to estimate where you'd be at reset if your average usage continued. This doesn't predict breaks or future spikes.",
            "Comparamos ambos para estimar cómo llegarías al reinicio si mantuvieras tu uso medio. No predice pausas ni picos futuros."
        )
    }

    public func sessionPaceText(_ status: SessionPaceStatus) -> String {
        switch status {
        case .noUsage:
            text("No session usage reported yet", "Aún no hay uso registrado en esta sesión")
        case .newSession:
            text("New session · measuring pace", "Sesión nueva · calculando ritmo")
        case .measuring:
            text("Measuring this session's pace", "Calculando el ritmo de esta sesión")
        case .unavailable:
            text("Session pace unavailable", "Ritmo de sesión no disponible")
        case .onTrack:
            text(
                "At this pace, you should make it to the session reset",
                "A este ritmo, llegarías al reinicio de sesión"
            )
        case .limitIn(let duration):
            text(
                "At this pace, you could hit the session limit in \(UsagePaceFormatter.string(duration: duration))",
                "A este ritmo, podrías agotar la sesión en \(UsagePaceFormatter.string(duration: duration))"
            )
        }
    }

    public func resetLabel(for snapshot: ProviderUsageSnapshot) -> String {
        if snapshot.displaysWeeklyReset { return text("WEEKLY RESET", "RESETEO SEM.") }
        return snapshot.availability == .available
            ? text("RESETS", "RESETEO") : text("BACK IN", "DISPONIBLE EN")
    }

    public func resetText(for snapshot: ProviderUsageSnapshot, now: Date) -> String {
        let duration = UsageResetFormatter.string(until: snapshot.availabilityReset, relativeTo: now)
        if snapshot.displaysWeeklyReset {
            return text("Weekly reset in \(duration)", "Reseteo semanal en \(duration)")
        }
        return snapshot.availability == .available
            ? text("Resets in \(duration)", "Reseteo en \(duration)")
            : text("Back in \(duration)", "Disponible en \(duration)")
    }
}
