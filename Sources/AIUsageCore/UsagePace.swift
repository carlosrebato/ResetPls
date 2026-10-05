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
            if !Self.sameWindow(last.reset, reset) || percent < last.percent {
                samples.removeAll()
            } else if date.timeIntervalSince(last.timestamp) < 30 {
                return
            }
        }
        samples.removeAll { date.timeIntervalSince($0.timestamp) > 3_600 }
        samples.append(Sample(timestamp: date, percent: percent, reset: reset))
        samples = Array(samples.suffix(121))
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
        guard primaryQuotaID == .weekly, source == .live, !isStale(at: now),
              weekly.isVerifiedWeekly,
              let used = weekly.usedPercent, used.isFinite, (0..<100).contains(used),
              let reset = weekly.resetsAt, reset > now,
              let duration = weekly.durationSeconds else { return nil }
        let start = reset.addingTimeInterval(-duration)
        let elapsed = observedAt.timeIntervalSince(start)
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
        } else if elapsed >= 48 * 60 * 60 {
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
        availability == .available && primaryQuotaID == .weekly
            && weekly.isVerifiedWeekly && weekly.resetsAt != nil
    }

    /// Compatibility entry point for the primary quota's shared assessment.
    /// It must never run a competing estimator or silently switch quota.
    public func paceEstimate(at now: Date) -> PaceEstimate? {
        guard availability == .available, source == .live, !isStale(at: now) else { return nil }
        if primaryQuotaID == .weekly {
            guard let assessment = weeklyRisk(at: now) else { return .insufficientData }
            switch assessment.state {
            case .roomToSpare, .onTrack: return .onTrackToReset
            case .atRisk, .highRisk:
                guard let duration = weekly.durationSeconds, let reset = weekly.resetsAt,
                      assessment.usedPercent > 0 else { return .insufficientData }
                let elapsed = max(observedAt.timeIntervalSince(reset.addingTimeInterval(-duration)), 86_400)
                let eta = elapsed * (100 - assessment.usedPercent) / assessment.usedPercent
                let deadline = observedAt.addingTimeInterval(eta)
                return .limitIn(max(60, deadline.timeIntervalSince(now)), quota: .weekly)
            }
        }
        return sessionPaceEstimate(at: now)
    }

    /// Presentation for services that expose a five-hour session. The global
    /// signal still considers both quotas, but session copy must describe the
    /// session rather than unexpectedly switching to the weekly window.
    public func sessionPaceEstimate(at now: Date) -> PaceEstimate? {
        guard availability == .available, source == .live, !isStale(at: now),
              session.usedPercent != nil else { return nil }
        switch sessionPaceAssessment(at: now)?.status {
        case .limitIn(let duration): return .limitIn(duration, quota: .session)
        case .onTrack, .noUsage: return .onTrackToReset
        case .newSession, .measuring, .unavailable, nil: return .insufficientData
        }
    }

    public func sessionPaceStatus(at now: Date) -> SessionPaceStatus? {
        sessionPaceAssessment(at: now)?.status
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
