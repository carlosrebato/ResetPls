import AIUsageMacServices
import AIUsageCore
import AppKit
import Foundation

@MainActor
enum ProviderDataAccessPicker {
    static func requestAccess(
        for provider: UsageProviderID,
        duringInitialConnection: Bool = false
    ) async throws -> Bool {
        let dataDirectory: ProviderDataDirectory = provider == .claude ? .claudeCode : .codex
        let providerName = provider == .claude ? "Claude" : "Codex"
        let localToolName = provider == .claude ? "Claude Code" : "Codex CLI"
        let folderName = provider == .claude ? ".claude" : ".codex"
        let language = AppLanguage.current
        let panel = NSOpenPanel()
        panel.title = duringInitialConnection
            ? language.text("Optional token history on this Mac", "Historial opcional de tokens de este Mac")
            : language.text(
                "Choose the \(providerName) token-history folder",
                "Elegir carpeta del historial de tokens de \(providerName)"
            )
        panel.message = duringInitialConnection
            ? language.text(
                "\(providerName) is connected. Optional: select \(folderName) to read the history of tokens consumed by \(localToolName) on this Mac and estimate their cost at API rates. ResetPls scans session files, which may contain conversation text, but does not store or send that text. Cancel to skip; quota percentages still work.",
                "\(providerName) está conectado. Opcional: selecciona \(folderName) para leer el historial de tokens consumidos por \(localToolName) en este Mac y estimar su coste a tarifas API. ResetPls examina archivos de sesiones, que pueden contener conversaciones, pero no guarda ni envía ese texto. Pulsa Cancelar para omitirlo; los porcentajes de cuota seguirán funcionando."
            )
            : language.text(
                "Select \(folderName) to read the history of tokens consumed by \(localToolName) on this Mac and estimate their cost at API rates. ResetPls scans session files, which may contain conversation text, but does not store or send that text. Quota percentages work without this access.",
                "Selecciona \(folderName) para leer el historial de tokens consumidos por \(localToolName) en este Mac y estimar su coste a tarifas API. ResetPls examina archivos de sesiones, que pueden contener conversaciones, pero no guarda ni envía ese texto. Los porcentajes de cuota funcionan sin este acceso."
            )
        panel.prompt = language.text("Use \(folderName)", "Usar \(folderName)")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.showsHiddenFiles = true

        let home = FileManager.default.homeDirectoryForCurrentUser
        let suggested: URL
        if provider == .claude {
            suggested = home.appendingPathComponent(".claude", isDirectory: true)
        } else {
            suggested = home.appendingPathComponent(".codex", isDirectory: true)
        }
        let selectedFolder = ProviderDataAccess.shared.resolvedURL(for: dataDirectory)
            ?? suggested
        // Open at the parent and preselect the hidden provider folder so the
        // required macOS consent is clear without making people navigate to a
        // hidden directory by hand.
        panel.directoryURL = selectedFolder.deletingLastPathComponent()
        panel.nameFieldStringValue = selectedFolder.lastPathComponent

        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let folder = panel.url else { return false }
        try ProviderDataAccess.shared.saveAccess(to: folder, for: dataDirectory)
        UserDefaults.standard.set(false, forKey: skippedHistoryKey(for: provider))
        return true
    }

    static func offerAccessDuringInitialConnection(for provider: UsageProviderID) async throws -> Bool {
        let directory: ProviderDataDirectory = provider == .claude ? .claudeCode : .codex
        guard !ProviderDataAccess.shared.hasUsableAccess(for: directory),
              !UserDefaults.standard.bool(forKey: skippedHistoryKey(for: provider)) else {
            return false
        }
        let granted = try await requestAccess(for: provider, duringInitialConnection: true)
        if !granted {
            UserDefaults.standard.set(true, forKey: skippedHistoryKey(for: provider))
        }
        return granted
    }

    private static func skippedHistoryKey(for provider: UsageProviderID) -> String {
        provider == .claude
            ? AppPreferenceKey.skippedClaudeTokenHistory
            : AppPreferenceKey.skippedCodexTokenHistory
    }
}

@MainActor
enum ClaudeDesktopAccessPicker {
    static func requestAccess() async throws -> Bool {
        try await ProviderDataAccessPicker.requestAccess(for: .claude)
    }
}

@MainActor
enum ClaudeCodeMetricsAccessPicker {
    static func requestAccess() async throws -> Bool {
        try await ProviderDataAccessPicker.requestAccess(for: .claude)
    }
}
