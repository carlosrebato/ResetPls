import AIUsageCore
import AIUsageDesignSystem
import AIUsageMacServices
import AppKit
import Combine
import SwiftUI

struct FloatingPanelView: View {
    static let size = NSSize(width: 256, height: 166)

    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var providerSelection: ProviderSelectionStore
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var now = Date.now
    @AppStorage(AppPreferenceKey.language) private var language: AppLanguage = .english
    private let onDock: (() -> Void)?

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(onDock: (() -> Void)? = nil) {
        self.onDock = onDock
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            UsageFloatingMetrics(
                snapshots: visibleSnapshots,
                now: now,
                language: language
            )
            .padding(.horizontal, 16)
            .padding(.top, 34)
            .padding(.bottom, 14)

            Button {
                if let onDock {
                    onDock()
                } else {
                    dismissWindow(id: "floating")
                }
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(UsageTheme.secondaryText)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 7)
            .padding(.trailing, 8)
            .help(language.text("Attach", "Acoplar"))
            .accessibilityLabel(language.text("Attach", "Acoplar"))
        }
        .frame(width: Self.size.width, height: panelSize.height)
        .background(UsageTheme.panelGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(UsageTheme.hairline, lineWidth: 1)
        }
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents()
        .background(FloatingWindowConfigurator(size: panelSize))
        .onReceive(timer) { now = $0 }
    }

    private var panelSize: NSSize {
        let extraHeight = visibleSnapshots.reduce(CGFloat.zero) { total, snapshot in
            var lines: [String] = []
            if let status = snapshot.sessionPaceStatus(at: now) {
                lines.append(language.sessionPaceText(status))
            }
            if let risk = snapshot.weeklyRisk(at: now) {
                lines.append(language.weeklyRiskText(risk))
            }
            return total + lines.reduce(CGFloat.zero) { $0 + paceLineHeight($1) }
        }
        return NSSize(width: Self.size.width, height: Self.size.height + extraHeight)
    }

    private func paceLineHeight(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(width: Self.size.width - 32, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return max(32, ceil(bounds.height) + 14)
    }

    private var visibleSnapshots: [ProviderUsageSnapshot] {
        providerSelection.filtering(store.snapshots)
    }
}

private struct FloatingWindowConfigurator: NSViewRepresentable {
    let size: NSSize
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configureWindow(for: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        configureWindow(for: view)
    }

    private func configureWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            let panelSize = size

            let desiredStyleMask: NSWindow.StyleMask = window is NSPanel
                ? [.borderless, .nonactivatingPanel]
                : [.borderless]
            if window.styleMask != desiredStyleMask {
                window.styleMask = desiredStyleMask
            }
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.level = .floating
            window.minSize = panelSize
            window.maxSize = panelSize
            window.setContentSize(panelSize)
        }
    }
}
