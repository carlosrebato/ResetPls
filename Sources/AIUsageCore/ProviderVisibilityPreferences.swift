import Foundation

public enum ProviderVisibilityPreferences {
    public static let migrationKey = "providerVisibilityMigrated"
    public static let emptySelectionRecoveryKey = "connectedProviderVisibilityRecovered"

    // UserDefaults is documented for concurrent use; Swift has not annotated it Sendable.
    nonisolated(unsafe) public static let store =
        UserDefaults(suiteName: AIUsageAppGroup.identifier) ?? .standard

    public static func key(for provider: UsageProviderID) -> String {
        "providerVisible.\(provider.rawValue)"
    }

    public static func isVisible(
        _ provider: UsageProviderID,
        in defaults: UserDefaults = store
    ) -> Bool {
        defaults.object(forKey: key(for: provider)) as? Bool ?? false
    }

    public static func setVisible(
        _ visible: Bool,
        for provider: UsageProviderID,
        in defaults: UserDefaults = store
    ) {
        defaults.set(visible, forKey: key(for: provider))
    }

    /// Returns the user's explicit selection, falling back to providers that
    /// already have cached data. The fallback repairs older iOS builds that
    /// connected accounts before provider visibility was initialized.
    public static func displayedProviders(
        cachedProviders: Set<UsageProviderID>,
        in defaults: UserDefaults = store
    ) -> [UsageProviderID] {
        let visible = UsageProviderID.allCases.filter { isVisible($0, in: defaults) }
        if !visible.isEmpty { return visible }
        return UsageProviderID.allCases.filter { cachedProviders.contains($0) }
    }

    /// Existing installations keep their current two-provider presentation.
    /// Fresh installations start with no provider selected; onboarding enables
    /// each provider only after the user explicitly chooses it.
    public static func migrateIfNeeded(
        onboardingCompleted: Bool,
        in defaults: UserDefaults = store
    ) {
        guard defaults.object(forKey: migrationKey) == nil else { return }
        for provider in UsageProviderID.allCases
        where defaults.object(forKey: key(for: provider)) == nil {
            defaults.set(onboardingCompleted, forKey: key(for: provider))
        }
        defaults.set(true, forKey: migrationKey)
    }

    /// Repair an older first-run flow that connected accounts without showing
    /// either one. Run only once so later explicit visibility choices remain.
    public static func recoverConnectedProvidersIfEmpty(
        onboardingCompleted: Bool,
        connectedProviders: Set<UsageProviderID>,
        in defaults: UserDefaults = store
    ) -> Set<UsageProviderID> {
        guard onboardingCompleted,
              defaults.object(forKey: emptySelectionRecoveryKey) == nil else { return [] }
        if UsageProviderID.allCases.contains(where: { isVisible($0, in: defaults) }) {
            defaults.set(true, forKey: emptySelectionRecoveryKey)
            return []
        }
        guard !connectedProviders.isEmpty else { return [] }
        for provider in connectedProviders { setVisible(true, for: provider, in: defaults) }
        defaults.set(true, forKey: emptySelectionRecoveryKey)
        return connectedProviders
    }
}

public enum ProviderOrderPreferences {
    public static let key = "providerDisplayOrder"

    public static func ordered(
        in defaults: UserDefaults = ProviderVisibilityPreferences.store
    ) -> [UsageProviderID] {
        let saved = defaults.stringArray(forKey: key) ?? []
        var result: [UsageProviderID] = []
        for raw in saved {
            guard let provider = UsageProviderID(rawValue: raw), !result.contains(provider) else {
                continue
            }
            result.append(provider)
        }
        result.append(contentsOf: UsageProviderID.allCases.filter { !result.contains($0) })
        return result
    }

    public static func setFirst(
        _ provider: UsageProviderID,
        in defaults: UserDefaults = ProviderVisibilityPreferences.store
    ) {
        defaults.set(
            ([provider] + ordered(in: defaults).filter { $0 != provider }).map(\.rawValue),
            forKey: key
        )
    }
}
