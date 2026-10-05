import AIUsageCore
import AIUsageDesignSystem
import Combine
import SwiftUI

struct IOSDashboardView: View {
    @EnvironmentObject private var store: IOSUsageStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppLanguage.preferenceKey) private var language: AppLanguage = .english
    @State private var now = Date.now
    @State private var showsSettings = ProcessInfo.processInfo.arguments.contains("--show-settings")

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            UsageTheme.stage.ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        header

                        UsageDetailedMetrics(
                            snapshots: store.snapshots,
                            now: now,
                            history: store.history,
                            language: language,
                            verticalExpansion: verticalExpansion(for: proxy.size.height)
                        )
                        .padding(.top, 18)

                        settingsButton
                            .padding(.top, 17)

                        if providersNeedingAction.isEmpty {
                            Spacer(minLength: 14)
                        }

                        disclaimer

                        if !providersNeedingAction.isEmpty {
                            connectionPanel
                                .padding(.top, 14)
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(proxy.size.height - 40, 0),
                        alignment: .top
                    )
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
                .refreshable { await store.refresh(force: true) }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { date in
            now = date
            if scenePhase == .active {
                Task { await store.refreshIfDue(at: date) }
            }
        }
        .onChange(of: store.snapshots) { _, _ in now = .now }
        .onChange(of: language) { _, value in value.persistForExtensions() }
        .sheet(isPresented: $showsSettings) {
            IOSSettingsView()
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(now, style: .time)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(UsageTheme.primaryText)
                Button {
                    Task { await store.refresh(force: true) }
                } label: {
                    freshnessLine
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.isRefreshing)
                .accessibilityLabel(language.text("Refresh usage", "Actualizar uso"))
                .accessibilityHint(language.text("Double tap to update", "Toca dos veces para actualizar"))
            }
        }
    }

    private var settingsButton: some View {
        Button {
            showsSettings = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11.5, weight: .semibold))
                Text(language.text("SETTINGS", "AJUSTES"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.15)
            }
        }
        .buttonStyle(SettingsFooterButtonStyle())
        .accessibilityHint(language.text(
            "Opens app settings",
            "Abre los ajustes de la aplicación"
        ))
    }

    @ViewBuilder
    private var freshnessLine: some View {
        if store.isRefreshing {
            Text(language.text("Updating…", "Actualizando…"))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(UsageTheme.mutedText)
        } else {
            let freshness = UsageFreshness(snapshots: store.snapshots, now: now)
            if freshness.kind == .unavailable {
                Text(language.text("No usage data", "Sin datos de uso"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(UsageTheme.mutedText)
            } else {
                HStack(spacing: 4) {
                    Text(freshnessText(freshness))
                        .foregroundStyle(freshness.kind == .cached ? UsageTheme.cached.opacity(0.82) : UsageTheme.mutedText)
                    Image(systemName: freshness.kind == .cached ? "clock.fill" : "checkmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(freshness.kind == .cached ? UsageTheme.cached.opacity(0.82) : UsageTheme.green.opacity(0.72))
                    Image(systemName: "hand.tap")
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundStyle(UsageTheme.mutedText.opacity(0.4))
                }
                .font(.system(size: 10.5, weight: .medium))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var providersNeedingAction: [UsageProviderID] {
        UsageProviderID.allCases.filter { provider in
            switch store.states[provider] ?? .temporarilyUnavailable {
            case .live, .cached, .stale: false
            case .setupRequired, .reauthRequired, .temporarilyUnavailable: true
            }
        }
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(connectionPanelTitle)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(UsageTheme.tertiaryText)
                Text(connectionPanelMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(UsageTheme.secondaryText)
            }

            ForEach(providersNeedingAction, id: \.self) { provider in
                connectionRow(provider)
            }
        }
        .padding(18)
        .usagePanel(cornerRadius: 16)
    }

    private func connectionRow(_ provider: UsageProviderID) -> some View {
        HStack(spacing: 12) {
            ProviderGlyph(provider: provider, size: 16)
                .frame(width: 28, height: 28)
                .background(UsageTheme.provider(provider).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UsageTheme.primaryText)
                Text(connectionMessage(provider))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UsageTheme.mutedText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(actionTitle(provider)) {
                Task {
                    if store.states[provider] == .temporarilyUnavailable {
                        await store.refresh(force: true)
                    } else {
                        await store.signIn(provider)
                    }
                }
            }
            .buttonStyle(UsagePillButtonStyle())
            .disabled(
                store.isRefreshing
                    || store.authenticatingProviders.contains(provider)
                    || store.isDemoMode
            )
        }
    }

    private var disclaimer: some View {
        Text(language.text(
            "Independent · Not affiliated with Anthropic or OpenAI · Credentials stay on device",
            "Independiente · Sin afiliación con Anthropic ni OpenAI · Credenciales en el dispositivo"
        ))
        .font(.system(size: 8.5, weight: .regular))
        .tracking(0.15)
        .foregroundStyle(UsageTheme.mutedText.opacity(0.55))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, -5)
    }

    private func connectionMessage(_ provider: UsageProviderID) -> String {
        switch store.states[provider] ?? .temporarilyUnavailable {
        case .setupRequired:
            return language.text(
                "Connect securely to read your current limits.",
                "Conecta de forma segura para consultar tus límites."
            )
        case .reauthRequired:
            return language.text(
                "Your session expired. Reconnect to resume updates.",
                "Tu sesión ha caducado. Reconecta para recuperar las actualizaciones."
            )
        case .temporarilyUnavailable:
            return language.text(
                "The service could not be reached. Your session is still saved.",
                "No se pudo contactar con el servicio. Tu sesión sigue guardada."
            )
        case .live, .cached, .stale:
            return store.messages[provider] ?? ""
        }
    }

    private var connectionPanelTitle: String {
        let states = providersNeedingAction.compactMap { store.states[$0] }
        if states.contains(.reauthRequired) {
            return language.text("SESSION EXPIRED", "SESIÓN CADUCADA")
        }
        if states.contains(.setupRequired) {
            return language.text("CONNECT A SERVICE", "CONECTA UN SERVICIO")
        }
        return language.text("UPDATE UNAVAILABLE", "ACTUALIZACIÓN NO DISPONIBLE")
    }

    private var connectionPanelMessage: String {
        let states = providersNeedingAction.compactMap { store.states[$0] }
        if states.contains(.reauthRequired), states.contains(.setupRequired) {
            return language.text(
                "Reconnect the expired session or connect another service.",
                "Reconecta la sesión caducada o conecta otro servicio."
            )
        }
        if states.contains(.reauthRequired) {
            return language.text(
                "Reconnect the affected service. Your other service keeps working.",
                "Reconecta el servicio afectado. El otro seguirá funcionando."
            )
        }
        if states.contains(.setupRequired) {
            return language.text(
                "Connect one or both services to start tracking your limits.",
                "Conecta uno o ambos servicios para empezar a seguir tus límites."
            )
        }
        return language.text(
            "Try again. Your saved connection and last data are unchanged.",
            "Vuelve a intentarlo. Tu conexión y el último dato siguen guardados."
        )
    }

    private func actionTitle(_ provider: UsageProviderID) -> String {
        switch store.states[provider] ?? .temporarilyUnavailable {
        case .setupRequired: language.text("Connect", "Conectar")
        case .reauthRequired: language.text("Reconnect", "Reconectar")
        case .temporarilyUnavailable: language.text("Retry", "Reintentar")
        case .live, .cached, .stale: ""
        }
    }

    private func freshnessText(_ freshness: UsageFreshness) -> String {
        let label = freshness.kind == .cached
            ? language.text("Last update", "Último dato")
            : language.text("Updated", "Actualizado")
        return "\(label) \(freshness.date.formatted(date: .omitted, time: .shortened))"
    }

    private func verticalExpansion(for availableHeight: CGFloat) -> CGFloat {
        min(max((availableHeight - 700) / 10, 0), 18)
    }
}

struct IOSOnboardingView: View {
    @EnvironmentObject private var store: IOSUsageStore
    @AppStorage(AppLanguage.preferenceKey) private var language: AppLanguage = .english
    let finish: () -> Void

    var body: some View {
        ZStack {
            UsageTheme.stage.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 52)

                    Text("RESETPLS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(UsageTheme.tertiaryText)

                    VStack(spacing: 10) {
                        Text(language.text(
                            "Your AI limits, at a glance.",
                            "Tus límites de IA, de un vistazo."
                        ))
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.7)
                            .foregroundStyle(UsageTheme.primaryText)
                            .multilineTextAlignment(.center)

                        Text(language.text(
                            "Connect at least one service to see when its limits reset and whether you're on track.",
                            "Conecta al menos un servicio para ver cuándo se reinician sus límites y si vas al ritmo adecuado."
                        ))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(UsageTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.top, 18)

                    onboardingPanel
                        .padding(.top, 30)

                    HStack(spacing: 7) {
                        Image(systemName: "lock")
                            .font(.system(size: 10, weight: .semibold))
                        Text(language.text(
                            "Read-only access · Credentials stay on this device",
                            "Acceso de solo lectura · Las credenciales se quedan en este dispositivo"
                        ))
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(UsageTheme.mutedText.opacity(0.76))
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)

                    HStack(spacing: 12) {
                        Button(language.text("Not now", "Ahora no"), action: finish)
                            .buttonStyle(OnboardingSecondaryButtonStyle())

                        Button(language.text("Continue", "Continuar"), action: finish)
                            .buttonStyle(OnboardingPrimaryButtonStyle())
                            .disabled(!canContinue)
                            .opacity(canContinue ? 1 : 0.42)
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 34)
                }
                .frame(maxWidth: .infinity, minHeight: 760)
                .padding(.horizontal, 28)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .task { await store.refresh() }
        .onChange(of: language) { _, value in value.persistForExtensions() }
    }

    private var onboardingPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(language.text("CONNECT YOUR SERVICES", "CONECTA TUS SERVICIOS"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(UsageTheme.tertiaryText)
                Text(language.text(
                    "Start with one or connect both. You can change this later in Settings.",
                    "Empieza con uno o conecta ambos. Podrás cambiarlo después en Ajustes."
                ))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UsageTheme.secondaryText)
            }

            ForEach(UsageProviderID.allCases, id: \.self) { provider in
                onboardingRow(provider)
            }
        }
        .padding(18)
        .usagePanel(cornerRadius: 16)
    }

    private func onboardingRow(_ provider: UsageProviderID) -> some View {
        HStack(spacing: 12) {
            ProviderGlyph(provider: provider, size: 16)
                .frame(width: 30, height: 30)
                .background(
                    UsageTheme.provider(provider).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 8)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UsageTheme.primaryText)
                Text(rowMessage(provider))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UsageTheme.mutedText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isConnected(provider) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(UsageTheme.green)
                    .accessibilityLabel(language.text("Connected", "Conectado"))
            } else {
                Button(rowActionTitle(provider)) {
                    Task { await store.signIn(provider) }
                }
                .buttonStyle(UsagePillButtonStyle())
                .disabled(
                    store.isRefreshing
                        || store.authenticatingProviders.contains(provider)
                        || store.isDemoMode
                )
            }
        }
    }

    private var canContinue: Bool {
        UsageProviderID.allCases.contains(where: isConnected)
    }

    private func isConnected(_ provider: UsageProviderID) -> Bool {
        switch store.states[provider] ?? .setupRequired {
        case .live, .cached, .stale: true
        case .setupRequired, .reauthRequired, .temporarilyUnavailable: false
        }
    }

    private func rowMessage(_ provider: UsageProviderID) -> String {
        if isConnected(provider) {
            return language.text("Ready to track your limits.", "Listo para seguir tus límites.")
        }
        if store.states[provider] == .reauthRequired {
            return language.text(
                "Your previous session expired. Reconnect to continue.",
                "Tu sesión anterior ha caducado. Reconecta para continuar."
            )
        }
        return language.text(
            "Connect securely to read your current limits.",
            "Conecta de forma segura para consultar tus límites."
        )
    }

    private func rowActionTitle(_ provider: UsageProviderID) -> String {
        store.states[provider] == .reauthRequired
            ? language.text("Reconnect", "Reconectar")
            : language.text("Connect", "Conectar")
    }
}

private struct SettingsFooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(UsageTheme.tertiaryText.opacity(configuration.isPressed ? 0.58 : 0.78))
            .frame(width: 132, height: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.86))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                UsageTheme.green.opacity(configuration.isPressed ? 0.76 : 1),
                in: RoundedRectangle(cornerRadius: 13)
            )
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(UsageTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.08 : 0.045),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(UsageTheme.hairline, lineWidth: 1)
            }
    }
}
