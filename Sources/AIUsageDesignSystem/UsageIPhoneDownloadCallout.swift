#if os(macOS)
import AIUsageCore
import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI

public struct UsageIPhoneDownloadCallout: View {
    private let language: AppLanguage
    @State private var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(language: AppLanguage, initiallyExpanded: Bool = false) {
        self.language = language
        _expanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(UsageTheme.secondaryText)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 5) {
                    Text(language.text("ResetPls for iPhone", "ResetPls para iPhone"))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(UsageTheme.primaryText)
                    Text(language.text("Check your limits on your iPhone too", "Consulta tus límites también en el iPhone"))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(UsageTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { expanded.toggle() }
                } label: {
                    Image(language.text("AppStoreBadge-en", "AppStoreBadge-es"), bundle: .module)
                        .resizable().scaledToFit().frame(width: 120, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text("Download on the App Store", "Descargar en el App Store"))
                .accessibilityValue(expanded ? language.text("Expanded", "Expandido") : language.text("Collapsed", "Contraído"))
                .accessibilityHint(language.text("Show or hide the QR code", "Muestra u oculta el código QR"))
            }
            if expanded, let image = qrImage {
                Image(nsImage: image)
                    .interpolation(.none).resizable().scaledToFit()
                    .frame(width: 164, height: 164)
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(language.text("ResetPls for iPhone download QR code", "QR de descarga de ResetPls para iPhone"))
                    .transition(.opacity)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1) }
    }

    private var qrImage: NSImage? {
        // Temporary destination until the App Store listing becomes available.
        let url = ProjectLinks.website + language.text("/#iphone", "/es/#iphone")
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
#endif
