import Foundation

public enum PollingPolicy {
    public static func interval(for severity: UsageSeverity, consecutiveFailures: Int) -> Duration {
        if consecutiveFailures > 0 {
            let seconds = min(600, 30 * (1 << min(consecutiveFailures - 1, 5)))
            return .seconds(seconds)
        }

        // Both providers can rate-limit aggressive polling; visual warnings
        // must not turn into more requests and more cached responses.
        return .seconds(300)
    }
}
