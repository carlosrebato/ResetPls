import AIUsageCore
import SwiftUI

/// Shared privacy message: local token files can contain conversation text,
/// so do not promise that files containing conversations are never read.
public struct UsagePrivacyCallout: View {
    private let language: AppLanguage

    public init(language: AppLanguage) { self.language = language }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(UsageTheme.green)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(language.text("Your data stays on your device", "Tus datos se quedan en tu dispositivo"))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(UsageTheme.primaryText)
                Text(language.text(
                    "Usage counters are processed locally with read-only access. ResetPls does not store or send the content of your conversations.",
                    "Los contadores de uso se procesan localmente y con acceso de solo lectura. ResetPls no almacena ni envía el contenido de tus conversaciones."))
                    .font(.system(size: 11.5, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(UsageTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UsageTheme.green.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
