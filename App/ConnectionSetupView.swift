import AIUsageCore
import AIUsageDesignSystem
import AIUsageMacServices
import AIUsageProviderServices
import AppKit
import SwiftUI

struct ConnectionSetupView: View {
    @EnvironmentObject private var store: UsageStore
    let statuses: [ProviderConnectionStatus]
    let isRefreshing: Bool
    let errorMessage: String?
    let retry: () -> Void
    let grantClaudeDesktopAccess: () -> Void
    @AppStorage(AppPreferenceKey.language) private var language: AppLanguage = .english

    private var pending: [ProviderConnectionStatus] {
        statuses.filter { status in
            switch status.phase {
            case .checking, .actionRequired: true
            case .connected, .retrying: false
            }
        }
    }

    var body: some View {
        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(panelTitle)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(UsageTheme.tertiaryText)
                    Text(panelMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(UsageTheme.secondaryText)
                }

                ForEach(pending) { status in
                    connectionRow(status)
                }

                if let visibleError = errorMessage {
                    Text(visibleError)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(UsageTheme.red)
                }
            }
            .padding(18)
            .usagePanel(cornerRadius: 16)
        }
    }

    private func connectionRow(_ status: ProviderConnectionStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: status.id.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UsageTheme.provider(status.id))
                .frame(width: 28, height: 28)
                .background(UsageTheme.provider(status.id).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(status.id.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UsageTheme.primaryText)
                Text(status.message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UsageTheme.mutedText)
                    .lineLimit(2)
            }

            Spacer()

            if let action = status.action {
                Button(actionLabel(action, status: status)) {
                    perform(action, provider: status.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshing)
            } else if case .checking = status.phase {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var panelTitle: String {
        pending.contains { $0.dataState == .reauthRequired }
            ? language.text("SESSION EXPIRED", "SESIÓN CADUCADA")
            : language.text("CONNECT A SERVICE", "CONECTA UN SERVICIO")
    }

    private var panelMessage: String {
        let states = pending.map(\.dataState)
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
        return language.text(
            "Connect one or both services to start tracking your limits.",
            "Conecta uno o ambos servicios para empezar a seguir tus límites."
        )
    }

    private func actionLabel(
        _ action: ProviderSetupAction,
        status: ProviderConnectionStatus
    ) -> String {
        switch action {
        case .grantPermission: language.text("Grant access", "Dar acceso")
        case .signIn:
            status.dataState == .reauthRequired
                ? language.text("Reconnect \(status.id.displayName)", "Reconectar \(status.id.displayName)")
                : language.text("Connect \(status.id.displayName)", "Conectar \(status.id.displayName)")
        case .install: language.text("Install", "Instalar")
        case .retry: language.text("Retry", "Reintentar")
        }
    }

    private func perform(_ action: ProviderSetupAction, provider: UsageProviderID) {
        switch action {
        case .grantPermission where provider == .claude:
            grantClaudeDesktopAccess()
        case .grantPermission, .retry:
            retry()
        case .signIn:
            Task { @MainActor in
                _ = await store.connect(provider)
            }
        case .install:
            ProviderAppLauncher.open(provider, installationFallback: true)
        }
    }
}

enum ProviderAppLauncher {
    static func open(_ provider: UsageProviderID, installationFallback: Bool) {
        if !installationFallback, openInstalledApplication(provider) { return }
        guard let url = downloadURL(provider) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func openInstalledApplication(_ provider: UsageProviderID) -> Bool {
        if provider == .claude,
           let deepLink = URL(string: "claude://claude.ai/new"),
           NSWorkspace.shared.open(deepLink) {
            return true
        }

        let names = provider == .claude ? ["Claude"] : ["Codex", "ChatGPT"]
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]
        for root in roots {
            for name in names {
                let url = root.appendingPathComponent("\(name).app", isDirectory: true)
                if FileManager.default.fileExists(atPath: url.path) {
                    if NSWorkspace.shared.open(url) { return true }
                }
            }
        }
        return false
    }

    private static func downloadURL(_ provider: UsageProviderID) -> URL? {
        switch provider {
        case .claude: URL(string: "https://claude.com/download")
        case .codex: URL(string: "https://chatgpt.com/download/")
        }
    }
}
