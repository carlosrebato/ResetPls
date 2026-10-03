import SwiftUI
import AppKit
import WidgetKit
import AIUsageCore
import AIUsageDesignSystem

@main struct Capture {
    @MainActor static func main() throws {
        let store = UsageStore()
        let selection = ProviderSelectionStore()
        precondition(store.snapshots[0].paceEstimate(at: .now) == .onTrackToReset)
        precondition(store.snapshots[1].paceEstimate(at: .now) == .limitIn(1800, quota: .session))
        UserDefaults.standard.setVolatileDomain([AppLanguage.preferenceKey: "es", "menuBarExpanded": false], forName: UserDefaults.argumentDomain)
        let output = CommandLine.arguments[1]
        if CommandLine.arguments.contains("--widgets-only") {
            let entry = UsageWidgetEntry(date: .now, snapshots: store.snapshots)
            try render(UsageWidgetView(family: .systemSmall, entry: entry)
                .padding(16).frame(width: 170, height: 170).background(UsageTheme.panelGradient)
                .clipShape(RoundedRectangle(cornerRadius: 22)), to: output + "/widget-small.png")
            try render(UsageWidgetView(family: .systemMedium, entry: entry)
                .padding(16).frame(width: 448, height: 200).background(UsageTheme.panelGradient)
                .clipShape(RoundedRectangle(cornerRadius: 22)), to: output + "/widget-medium.png")
            return
        }
        try render(StandardMenuBar(snapshots: store.snapshots), to: output + "/mac-menubar.png", scale: 6)
        if CommandLine.arguments.contains("--menubar-only") { return }
        try render(MenuBarView().environmentObject(store).environmentObject(selection), to: output + "/mac-compact.png")
        UserDefaults.standard.setVolatileDomain([AppLanguage.preferenceKey: "es", "menuBarExpanded": true], forName: UserDefaults.argumentDomain)
        try render(MenuBarView().environmentObject(store).environmentObject(selection), to: output + "/mac-expanded.png")
        try render(FloatingPanelView().environmentObject(store).environmentObject(selection), to: output + "/mac-floating.png")
    }
    @MainActor static func render<V: View>(_ view: V, to path: String, scale: CGFloat = 3) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark).environment(\.locale, Locale(identifier: "es_ES")))
        renderer.scale = scale
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data:tiff), let data=bitmap.representation(using:.png,properties:[:]) else { fatalError("Native render failed") }
        try data.write(to:URL(fileURLWithPath:path))
        print(path, bitmap.pixelsWide, bitmap.pixelsHigh)
    }
}

// Neutral macOS scene, rendered with SF Symbols and the app's original status item.
private struct StandardMenuBar: View {
    let snapshots: [ProviderUsageSnapshot]
    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 15))
            Text("Finder").fontWeight(.semibold)
            Text("Archivo")
            Text("Edición")
            Text("Visualización")
            Text("Ir")
            Text("Ventana")
            Text("Ayuda")
            Spacer()
            MenuBarUsageImageContent(snapshots: snapshots, colorScheme: .dark, showResetTimes: false, now: .now)
            Image(systemName: "battery.100percent").font(.system(size: 17))
            Image(systemName: "wifi")
            Image(systemName: "switch.2")
            Text("Jue 1 oct  10:42").monospacedDigit()
        }
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.94))
        .padding(.horizontal, 20)
        .frame(width: 1440, height: 28)
        .background(Color(red: 0.12, green: 0.15, blue: 0.16))
    }
}
