import AIUsageCore
import SwiftUI

/// A platform download link with the same presentation as UsagePrivacyCallout.
public struct UsageMacDownloadCallout: View {
    private let language: AppLanguage

    public init(language: AppLanguage) { self.language = language }

    public var body: some View {
        Link(destination: URL(string: "https://resetpls.app")!) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(UsageTheme.green)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 5) {
                    Text(language.text("ResetPls for Mac · Free", "ResetPls para Mac · Gratis"))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(UsageTheme.primaryText)
                    Text(language.text(
                        "Your usage limits in the menu bar",
                        "Tus límites de uso en la barra de menú"
                    ))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(UsageTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text(language.text("Download", "Descargar"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UsageTheme.green)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.05), in: Capsule())
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UsageTheme.green.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

}
