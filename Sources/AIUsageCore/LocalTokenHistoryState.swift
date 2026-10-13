import Foundation

public enum LocalTokenReadStatus: Equatable, Sendable {
    case unknown, reading, ready, failed
}

public enum LocalTokenHistoryState: Equatable, Sendable {
    case notEnabled, awaitingRead, checking, enabled, noActivity, accessLost, readFailed

    public static func resolve(hasStoredAccess: Bool, hasUsableAccess: Bool,
                               hasTotals: Bool, readStatus: LocalTokenReadStatus) -> Self {
        guard hasUsableAccess else { return hasStoredAccess ? .accessLost : .notEnabled }
        switch readStatus {
        case .reading: return .checking
        case .failed: return .readFailed
        case .ready: return hasTotals ? .enabled : .noActivity
        case .unknown: return hasTotals ? .enabled : .awaitingRead
        }
    }

    public var needsAttention: Bool { self == .accessLost || self == .readFailed }
    public var requestsReading: Bool { self == .readFailed || self == .awaitingRead }

    public func title(language: AppLanguage) -> String {
        switch self {
        case .notEnabled: language.text("Token history · Not enabled", "Historial de tokens · Sin activar")
        case .awaitingRead: language.text("Token history · Ready to read", "Historial de tokens · Listo para leer")
        case .checking: language.text("Reading token history…", "Leyendo historial de tokens…")
        case .enabled: language.text("Token history · Enabled", "Historial de tokens · Activado")
        case .noActivity: language.text("No local activity recorded", "Sin actividad local registrada")
        case .accessLost: language.text("Token folder access lost", "Sin acceso a la carpeta de tokens")
        case .readFailed: language.text("Could not read token history", "No se pudo leer el historial de tokens")
        }
    }

    public func actionTitle(language: AppLanguage) -> String {
        switch self {
        case .notEnabled: language.text("Enable…", "Activar…")
        case .awaitingRead: language.text("Read tokens", "Leer tokens")
        case .accessLost: language.text("Restore access…", "Restablecer acceso…")
        case .readFailed: language.text("Retry", "Reintentar")
        case .checking: language.text("Reading…", "Leyendo…")
        case .enabled, .noActivity: language.text("Change folder…", "Cambiar carpeta…")
        }
    }

    public static func explanation(language: AppLanguage) -> String {
        language.text(
            "Access to token history shows the tokens consumed on this Mac and what they would cost at API rates. It is not required for quota percentages or pace predictions.",
            "Dar acceso al historial de tokens permite mostrar los tokens consumidos en este Mac y una estimación de cuánto costarían a tarifas API. No es necesario para mostrar el porcentaje de cuota utilizada ni las predicciones de ritmo.")
    }

    public static func managementExplanation(language: AppLanguage) -> String {
        language.text(
            "Token history shows local token usage and its estimated cost at API rates. Quota percentages and pace predictions do not require it.",
            "El historial de tokens muestra el consumo de este Mac y su coste estimado a tarifas API. Los porcentajes de cuota y las predicciones de ritmo no requieren este acceso.") + "\n\n" + language.text(
            "To enable it, select the .claude folder for Claude and the .codex folder for Codex from Options… above.",
            "Para activarlo, selecciona la carpeta .claude para Claude y .codex para Codex desde «Opciones…», más arriba.")
    }

    public func help(language: AppLanguage) -> String {
        switch self {
        case .notEnabled: language.text("Local token history is not enabled. You can enable it in Settings; quota percentages work without it.", "El historial de tokens de este Mac no está activado. Puedes activarlo en Ajustes; los porcentajes de cuota funcionan sin él.")
        case .awaitingRead: language.text("Folder access is enabled. Read the token history in Settings to load the local totals.", "El acceso a la carpeta está activado. Lee el historial de tokens desde Ajustes para cargar los totales de este Mac.")
        case .checking: language.text("Reading the token history on this Mac.", "Leyendo el historial de tokens consumidos en este Mac.")
        case .enabled: Self.explanation(language: language)
        case .noActivity: language.text("Folder access is working, but no tokens were recorded on this Mac for the current period.", "El acceso a la carpeta funciona, pero no hay tokens consumidos registrados en este Mac para el periodo actual.")
        case .accessLost: language.text("ResetPls can no longer access the token folder. Restore access in Settings; quota percentages still work.", "ResetPls ya no puede acceder a la carpeta de tokens. Restablece el acceso en Ajustes; los porcentajes de cuota siguen funcionando.")
        case .readFailed: language.text("Token history could not be read. Retry in Settings; quota percentages still work.", "No se pudo leer el historial de tokens. Reintenta la lectura en Ajustes; los porcentajes de cuota siguen funcionando.")
        }
    }
}
