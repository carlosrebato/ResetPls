import AIUsageCore
import AIUsageDesignSystem
import SwiftUI

struct IOSSettingsView: View {
    @EnvironmentObject private var store: IOSUsageStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.preferenceKey) private var language: AppLanguage = .english
    @AppStorage("iosRefreshOnActivation") private var refreshOnActivation = true

    var body: some View {
        NavigationStack {
            ZStack {
                UsageTheme.stage.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        providersSection
                        preferencesSection
                        privacyNote
                        supportSection
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(language.text("Settings", "Ajustes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(UsageTheme.stage, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(IOSSettingsPalette.secondary)
                    }
                    .accessibilityLabel(language.text("Close settings", "Cerrar ajustes"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .onChange(of: language) { _, value in value.persistForExtensions() }
    }

    private var providersSection: some View {
        settingsSection(language.text("Accounts", "Cuentas")) {
            providerRow(.claude)
            settingsDivider
            providerRow(.codex)
        }
    }

    private func providerRow(_ provider: UsageProviderID) -> some View {
        let state = store.states[provider] ?? .setupRequired
        let connected = isConnected(state)
        let color = store.isDemoMode ? UsageTheme.mock : stateColor(state)

        return HStack(spacing: 13) {
            ProviderGlyph(provider: provider, size: 18, color: IOSSettingsPalette.glyph)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(provider == .claude ? "Claude" : "Codex")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(IOSSettingsPalette.title)

                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .shadow(color: color.opacity(0.55), radius: 4)
                    Text(store.isDemoMode
                        ? language.text("Demo data", "Datos de demo")
                        : stateText(state)
                    )
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(IOSSettingsPalette.secondary)
                }
            }

            Spacer(minLength: 10)

            if store.isDemoMode {
                Text(language.text("PREVIEW", "PREVIA"))
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.05)
                    .foregroundStyle(UsageTheme.mock.opacity(0.9))
            } else {
                Button(providerActionTitle(state)) {
                    Task {
                        if connected {
                            await store.signOut(provider)
                        } else if state == .temporarilyUnavailable {
                            await store.refresh(force: true)
                        } else {
                            await store.signIn(provider)
                        }
                    }
                }
                .buttonStyle(ConnectionButtonStyle(connected: connected))
                .disabled(store.isRefreshing || store.authenticatingProviders.contains(provider))
            }
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 70)
    }

    private var preferencesSection: some View {
        settingsSection(language.text("Preferences", "Preferencias")) {
            preferenceRow(
                systemName: "arrow.triangle.2.circlepath",
                title: language.text("Refresh on open", "Actualizar al abrir"),
                subtitle: language.text(
                    "Update limits when you return",
                    "Actualiza los límites cuando vuelves"
                ),
                isOn: $refreshOnActivation
            )

            settingsDivider
            languageRow
        }
    }

    private var languageRow: some View {
        HStack(spacing: 13) {
            settingsIcon("globe")

            VStack(alignment: .leading, spacing: 3) {
                Text(language.text("Language", "Idioma")).settingsRowTitle()
                Text(language.text("Used throughout the app", "Se aplica a toda la app"))
                    .settingsRowSubtitle()
            }

            Spacer(minLength: 10)

            Menu {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        language = option
                    } label: {
                        if option == language {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(language.displayName)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(IOSSettingsPalette.buttonText)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.white.opacity(0.05), in: Capsule())
            }
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 68)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(IOSSettingsPalette.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 5) {
                Text(language.text(
                    "ResetPls only reads usage counters",
                    "ResetPls solo consulta contadores de uso"
                ))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(IOSSettingsPalette.title)
                Text(language.text(
                    "They’re processed on this iPhone. Your conversations are never read, stored, or sent.",
                    "Se procesan en este iPhone. Tus conversaciones nunca se leen, guardan ni envían."
                ))
                .font(.system(size: 11.5, weight: .medium))
                .lineSpacing(3)
                .foregroundStyle(IOSSettingsPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IOSSettingsPalette.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var supportSection: some View {
        settingsSection(language.text("Support", "Soporte")) {
            ShareLink(item: store.diagnosticReport()) {
                HStack(spacing: 13) {
                    settingsIcon("square.and.arrow.up")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(language.text("Export diagnostic", "Exportar diagnóstico")).settingsRowTitle()
                        Text(language.text(
                            "Limits and update status only. No credentials.",
                            "Solo límites y estado de actualización. Sin credenciales."
                        )).settingsRowSubtitle()
                    }
                    Spacer()
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 68)
            }
            .buttonStyle(.plain)
            settingsDivider
            supportRow(
                language.text("Help", "Ayuda"),
                systemName: "questionmark.circle",
                destination: ProjectLinks.help
            )
            settingsDivider
            supportRow(
                language.text("Privacy policy", "Política de privacidad"),
                systemName: "hand.raised",
                destination: ProjectLinks.privacy
            )
            settingsDivider
            supportRow(
                language.text("Report an issue", "Informar de un problema"),
                systemName: "exclamationmark.bubble",
                destination: ProjectLinks.reportIssue
            )
        }
    }

    private func supportRow(_ title: String, systemName: String, destination: String) -> some View {
        Link(destination: URL(string: destination)!) {
            HStack(spacing: 13) {
                settingsIcon(systemName)
                Text(title).settingsRowTitle()
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(IOSSettingsPalette.faint)
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 5) {
            Text("ResetPls \(versionText)")
                .monospacedDigit()
            Text(language.text(
                "Estimated API equivalent · current reset period · USD",
                "Equivalente API estimado · periodo de reinicio actual · USD"
            ))
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundStyle(IOSSettingsPalette.faint)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel(title)
                .padding(.leading, 3)
            VStack(spacing: 0) { content() }
                .background(Color.white.opacity(0.032), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.065), lineWidth: 1)
                }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased(with: language.locale))
            .font(.system(size: 10.5, weight: .bold))
            .tracking(1.7)
            .foregroundStyle(IOSSettingsPalette.faint)
    }

    private func preferenceRow(
        systemName: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 13) {
            settingsIcon(systemName)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).settingsRowTitle()
                Text(subtitle).settingsRowSubtitle()
            }
            Spacer(minLength: 10)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(IOSSettingsPalette.accent)
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 68)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.055))
            .frame(height: 1)
            .padding(.leading, 66)
    }

    private func settingsIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(IOSSettingsPalette.icon)
            .frame(width: 32, height: 32)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func isConnected(_ state: ProviderDataState) -> Bool {
        switch state {
        case .live, .cached, .stale: true
        case .setupRequired, .reauthRequired, .temporarilyUnavailable: false
        }
    }

    private func stateColor(_ state: ProviderDataState) -> Color {
        switch state {
        case .live: IOSSettingsPalette.accent
        case .cached, .stale: UsageTheme.cached
        case .setupRequired: UsageTheme.mutedText
        case .reauthRequired: UsageTheme.amber
        case .temporarilyUnavailable: UsageTheme.red
        }
    }

    private func stateText(_ state: ProviderDataState) -> String {
        switch state {
        case .live: language.text("Connected", "Conectado")
        case .cached: language.text("Cached", "En caché")
        case .stale: language.text("Needs update", "Necesita actualizar")
        case .setupRequired: language.text("Not connected", "Sin conectar")
        case .reauthRequired: language.text("Session expired", "Sesión caducada")
        case .temporarilyUnavailable: language.text("Temporarily unavailable", "No disponible temporalmente")
        }
    }

    private func providerActionTitle(_ state: ProviderDataState) -> String {
        switch state {
        case .live, .cached, .stale: language.text("Disconnect", "Desconectar")
        case .setupRequired: language.text("Connect", "Conectar")
        case .reauthRequired: language.text("Reconnect", "Reconectar")
        case .temporarilyUnavailable: language.text("Retry", "Reintentar")
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "v\(version) (\(build))"
    }
}

private enum IOSSettingsPalette {
    static let title = Color(red: 244 / 255, green: 244 / 255, blue: 246 / 255)
    static let buttonText = Color(red: 216 / 255, green: 216 / 255, blue: 220 / 255)
    static let icon = Color(red: 194 / 255, green: 196 / 255, blue: 202 / 255)
    static let glyph = Color(red: 232 / 255, green: 232 / 255, blue: 234 / 255)
    static let secondary = Color(red: 144 / 255, green: 146 / 255, blue: 154 / 255)
    static let faint = Color(red: 116 / 255, green: 118 / 255, blue: 126 / 255)
    static let accent = Color(red: 62 / 255, green: 207 / 255, blue: 142 / 255)
}

private struct ConnectionButtonStyle: ButtonStyle {
    let connected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(connected ? IOSSettingsPalette.buttonText : Color.black.opacity(0.78))
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(
                connected ? Color.white.opacity(0.06) : IOSSettingsPalette.accent,
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension Text {
    func settingsRowTitle() -> some View {
        font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(IOSSettingsPalette.title)
    }

    func settingsRowSubtitle() -> some View {
        font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(IOSSettingsPalette.secondary)
            .lineLimit(2)
    }
}
