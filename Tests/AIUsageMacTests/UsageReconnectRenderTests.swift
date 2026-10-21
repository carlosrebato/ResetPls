import AIUsageCore
import AIUsageDesignSystem
import AppKit
import SwiftUI
import Testing
import Vision

struct UsageReconnectRenderTests {
    @Test @MainActor func reconnectReplacesPaceInEveryPanelAndLanguage() throws {
        let now = Date.now
        let snapshot = ProviderUsageSnapshot(id: .claude,
            session: UsageWindow(usedPercent: 15, resetsAt: now.addingTimeInterval(7200)),
            weekly: UsageWindow(usedPercent: 50, resetsAt: now.addingTimeInterval(345600)),
            observedAt: now.addingTimeInterval(-3600), source: .cached, message: nil)
        for language in [AppLanguage.english, .spanish] {
            for state in [ProviderDataState.reauthRequired, .cached, .stale] {
            for panel in 0..<3 {
                let view: AnyView = switch panel {
                case 0: AnyView(UsageDetailedMetrics(snapshots: [snapshot], now: now, language: language))
                case 1: AnyView(UsageCompactMetrics(snapshots: [snapshot], now: now, language: language))
                default: AnyView(UsageFloatingMetrics(snapshots: [snapshot], now: now, language: language))
                }
                let renderer = ImageRenderer(content: view
                    .usageConnections([.claude: state]) { _ in }
                    .frame(width: panel == 2 ? 224 : 408)
                    .padding(20).background(Color.black))
                renderer.scale = 3
                let tiff = try #require(renderer.nsImage?.tiffRepresentation)
                let image = try #require(NSBitmapImageRep(data: tiff)?.cgImage)
                let request = VNRecognizeTextRequest()
                request.usesCPUOnly = true
                request.recognitionLevel = .accurate
                request.recognitionLanguages = [language == .english ? "en-US" : "es-ES"]
                try VNImageRequestHandler(cgImage: image).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ").uppercased()
                #expect(text.contains(language == .english ? "RECONNECTION REQUIRED" : "NECESITA RECONECTAR")
                    == (state == .reauthRequired))
                if state == .reauthRequired {
                    #expect(!text.contains("AT THIS PACE"))
                    #expect(!text.contains("A ESTE RITMO"))
                }
            }
            }
        }
    }
}
