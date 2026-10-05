import Foundation

public enum SessionPaceBasis: String, Codable, Sendable {
    case none, initialWindowAverage, windowAverage, blendedRecentTrend, recentTrend
}

public enum SessionPaceReason: String, Codable, Sendable {
    case estimated, noUsage, cached, sourceUnavailable, demoData, stale, invalidReading, exhausted
    case missingReset, invalidReset, invalidDuration, insufficientHistory
    case initialObservation, ambiguousProjection, stabilized
}

/// The evidence and result used by copy, signals and diagnostics on both platforms.
/// Rate and deadline are anchored to the actual observation, not the UI clock.
public struct SessionPaceAssessment: Equatable, Sendable {
    public let status: SessionPaceStatus?
    public let basis: SessionPaceBasis
    public let reason: SessionPaceReason
    public let observedAt: Date
    public let ratePercentPerSecond: Double?
    public let projectedPercentAtReset: Double?
    public let estimatedLimitAt: Date?
}

extension ProviderUsageSnapshot {
    public func sessionPaceAssessment(at now: Date) -> SessionPaceAssessment? {
        guard let percent = session.usedPercent else { return nil }
        func result(
            _ status: SessionPaceStatus?, _ reason: SessionPaceReason,
            basis: SessionPaceBasis = .none, rate: Double? = nil,
            projected: Double? = nil, deadline: Date? = nil
        ) -> SessionPaceAssessment {
            SessionPaceAssessment(
                status: status, basis: basis, reason: reason, observedAt: observedAt,
                ratePercentPerSecond: rate, projectedPercentAtReset: projected,
                estimatedLimitAt: deadline
            )
        }
        guard percent.isFinite, (0...100).contains(percent) else {
            return result(.unavailable, .invalidReading)
        }
        guard availability == .available else { return result(nil, .exhausted) }
        switch source {
        case .cached: return result(.unavailable, .cached)
        case .unavailable: return result(.unavailable, .sourceUnavailable)
        case .mock: return result(.measuring, .demoData)
        case .live: break
        }
        guard !isStale(at: now) else { return result(.unavailable, .stale) }
        // The provider's value, not the rounded display, determines absence of use.
        if percent == 0 { return result(.noUsage, .noUsage) }
        guard let reset = session.resetsAt else { return result(.unavailable, .missingReset) }
        guard reset.timeIntervalSince1970.isFinite, reset > observedAt, reset > now else {
            return result(.unavailable, .invalidReset)
        }

        let trend = UsagePaceHistory.recentSessionTrend(
            window: session, samples: paceHistory?.session ?? [], observedAt: observedAt
        )
        let rate: Double
        let basis: SessionPaceBasis
        let rateUncertainty: Double
        let earlyRiskProjection: Double?
        let isStarting: Bool
        // A half percentage-point guard band is a presentation tolerance,
        // not a statistical confidence interval or a forecast of future use.
        let readingTolerance = 0.5
        let remaining = reset.timeIntervalSince(observedAt)
        if let duration = session.durationSeconds {
            // Unknown long-term quotas must never be presented as session pace.
            guard duration.isFinite, duration > 0, duration <= 24 * 3_600 else {
                return result(.unavailable, .invalidDuration)
            }
            let elapsed = observedAt.timeIntervalSince(reset.addingTimeInterval(-duration))
            guard elapsed.isFinite, elapsed >= -60, elapsed < duration else {
                return result(.unavailable, .invalidReset)
            }
            let warmup = min(15 * 60, duration * 0.1)
            isStarting = elapsed < warmup
            let denominator = max(elapsed, 60)
            let average = percent / denominator
            let averageUncertainty = readingTolerance / denominator
            // Damp only the decision to warn during startup, never the rate
            // used to promise safety or to calculate the warning countdown.
            earlyRiskProjection = max(0, percent - readingTolerance)
                * (1 + remaining / max(elapsed, warmup))
            if let trend {
                // Ten minutes of flat readings cannot replace the entire
                // session. A full hour of verified recent evidence can.
                let weight = min(1, max(0, (trend.span - 600) / 3_000))
                rate = average * (1 - weight) + trend.rate * weight
                rateUncertainty = averageUncertainty * (1 - weight)
                    + (2 * readingTolerance / trend.span) * weight
                basis = weight > 0 ? .blendedRecentTrend
                    : elapsed < warmup ? .initialWindowAverage : .windowAverage
            } else {
                rate = average
                rateUncertainty = averageUncertainty
                basis = elapsed < warmup ? .initialWindowAverage : .windowAverage
            }
        } else if let trend {
            // Backward-compatible caches may lack duration. Only real trend
            // evidence can estimate those windows; the reason remains explicit.
            rate = trend.rate
            basis = .recentTrend
            rateUncertainty = 2 * readingTolerance / trend.span
            earlyRiskProjection = nil
            isStarting = false
        } else {
            return result(.unavailable, .insufficientHistory)
        }
        guard rate.isFinite, rate >= 0 else { return result(.unavailable, .invalidReading) }
        let projected = percent + rate * remaining
        guard projected.isFinite else { return result(.unavailable, .invalidReading) }
        let deadline = rate > 0 ? observedAt.addingTimeInterval((100 - percent) / rate) : nil
        let uncertainty = readingTolerance + rateUncertainty * remaining
        let prior = paceHistory?.sessionConclusion.flatMap { conclusion in
            UsagePaceHistory.sameWindow(conclusion.reset, reset)
                && conclusion.observedAt <= observedAt ? conclusion : nil
        }
        let status: SessionPaceStatus
        let reason: SessionPaceReason
        if projected - uncertainty > 100,
           !isStarting || (earlyRiskProjection ?? 0) > 100, let deadline {
            status = .limitIn(max(60, deadline.timeIntervalSince(now)))
            reason = .estimated
        } else if !isStarting, projected + uncertainty < 100 {
            status = .onTrack
            reason = .estimated
        } else if let prior {
            // Hysteresis inside the guard band: keep the conclusion but use
            // the current rate/deadline, not the previous reading's ETA.
            if prior.atRisk, let deadline {
                status = .limitIn(max(60, deadline.timeIntervalSince(now)))
            } else {
                status = .onTrack
            }
            reason = .stabilized
        } else {
            status = isStarting ? .newSession : .measuring
            reason = isStarting ? .initialObservation : .ambiguousProjection
        }
        return result(status, reason, basis: basis, rate: rate,
                      projected: projected, deadline: deadline)
    }
}

extension UsagePaceHistory {
    static func sameWindow(_ first: Date, _ second: Date) -> Bool {
        abs(first.timeIntervalSince(second)) <= 60
    }

    static func recentSessionTrend(
        window: UsageWindow, samples: [Sample], observedAt: Date
    ) -> (rate: Double, span: TimeInterval)? {
        guard let reset = window.resetsAt, let percent = window.usedPercent else { return nil }
        var recent = samples.filter {
            $0.percent.isFinite && (0...100).contains($0.percent)
                && sameWindow($0.reset, reset) && $0.timestamp <= observedAt
                && observedAt.timeIntervalSince($0.timestamp) <= 3_600
        }
        // When usage resumes after a verified pause, the old flat hour must
        // not dilute the new trend. The window average covers the transition
        // until the resumed segment has enough real observations.
        if recent.count >= 3, let last = recent.last,
           let pauseEnd = recent.indices.dropFirst().last(where: {
               recent[$0].percent == recent[$0 - 1].percent
           }), last.percent > recent[pauseEnd].percent {
            var pauseStart = pauseEnd - 1
            while pauseStart > 0 && recent[pauseStart - 1].percent == recent[pauseEnd].percent {
                pauseStart -= 1
            }
            if recent[pauseEnd].timestamp.timeIntervalSince(recent[pauseStart].timestamp) >= 600 {
                recent = Array(recent[pauseEnd...])
            }
        }
        guard recent.count >= 3, let first = recent.first, let last = recent.last,
              observedAt.timeIntervalSince(last.timestamp) <= 600,
              last.percent == percent else { return nil }
        let span = last.timestamp.timeIntervalSince(first.timestamp)
        guard span >= 600 else { return nil }
        let pairs = zip(recent, recent.dropFirst())
        guard pairs.allSatisfy({ $1.timestamp > $0.timestamp && $1.percent >= $0.percent }) else {
            return nil
        }
        let change = last.percent - first.percent
        if change <= 0.01 { return (0, span) }
        // A delayed isolated provider update must not be interpreted as a
        // sustained burst. The session-wide average is still available.
        guard change >= 1, pairs.filter({ $1.percent > $0.percent }).count >= 2 else {
            return nil
        }
        let times = recent.map { $0.timestamp.timeIntervalSince(first.timestamp) }
        let meanTime = times.reduce(0, +) / Double(recent.count)
        let meanPercent = recent.map(\.percent).reduce(0, +) / Double(recent.count)
        let variance = times.reduce(0) { $0 + pow($1 - meanTime, 2) }
        let covariance = zip(times, recent).reduce(0) {
            $0 + ($1.0 - meanTime) * ($1.1.percent - meanPercent)
        }
        let rate = max(0, covariance / variance)
        return rate.isFinite ? (rate, span) : nil
    }
}
