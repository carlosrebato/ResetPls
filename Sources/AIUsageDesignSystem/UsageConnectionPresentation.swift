import AIUsageCore
import SwiftUI

private struct UsageConnectionStatesKey: EnvironmentKey {
    static let defaultValue: [UsageProviderID: ProviderDataState] = [:]
}

private struct UsageReconnectKey: EnvironmentKey {
    static let defaultValue: (@MainActor @Sendable (UsageProviderID) -> Void)? = nil
}

extension EnvironmentValues {
    var usageConnectionStates: [UsageProviderID: ProviderDataState] {
        get { self[UsageConnectionStatesKey.self] }
        set { self[UsageConnectionStatesKey.self] = newValue }
    }

    var usageReconnect: (@MainActor @Sendable (UsageProviderID) -> Void)? {
        get { self[UsageReconnectKey.self] }
        set { self[UsageReconnectKey.self] = newValue }
    }
}

extension View {
    /// Authentication state comes from the connection, never from cached quota values.
    public func usageConnections(
        _ states: [UsageProviderID: ProviderDataState],
        reconnect: @escaping @MainActor @Sendable (UsageProviderID) -> Void
    ) -> some View {
        environment(\.usageConnectionStates, states)
            .environment(\.usageReconnect, reconnect)
    }
}

struct UsageReconnectIndicator: View {
    let language: AppLanguage

    var body: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(UsageTheme.cached)
            .accessibilityLabel(language.text("Reconnection required", "Necesita reconectar"))
    }
}
