import AIUsageCore
import AIUsageDesignSystem
import AppKit
import SwiftUI
import Testing
import Vision

struct UsageTrendHeaderRenderTests {
    @Test @MainActor func macKeepsTheTokenMetricInBothLanguages() throws {
        let now = Date.now
        let snapshot = ProviderUsageSnapshot(id: .claude,
            session: UsageWindow(usedPercent: 28, resetsAt: now.addingTimeInterval(7200)),
            weekly: UsageWindow(usedPercent: 43, resetsAt: now.addingTimeInterval(252000)),
            observedAt: now, source: .live, message: nil)
        for language in [AppLanguage.english, .spanish] {
            let renderer = ImageRenderer(content: UsageDetailedMetrics(
                snapshots: [snapshot], now: now, language: language)
                .frame(width: 408).padding(20).background(Color.black))
            renderer.scale = 3
            let tiff = try #require(renderer.nsImage?.tiffRepresentation)
            let image = try #require(NSBitmapImageRep(data: tiff)?.cgImage)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = [language == .english ? "en-US" : "es-ES"]
            try VNImageRequestHandler(cgImage: image).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").uppercased()
            #expect(text.contains("CLAUDE"))
            #expect(text.contains("TOKENS"))
            #expect(text.contains("RESET"))
            if ProcessInfo.processInfo.environment["RESETPLS_RENDER_WEEKLY_RESET"] == "1" {
                let png = try #require(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
                let suffix = language == .spanish ? "es" : "en"
                try png.write(to: URL(fileURLWithPath: "/private/tmp/resetpls-weekly-reset-\(suffix).png"))
            }
        }
    }

    @Test @MainActor func plainSelectorHeaderRendersWithoutANativeMenuControl() throws {
        let now = Date.now
        let history = UsageHistory(days: [UsageHistoryDay(date: now,
            claudeWeeklyPercent: 59, codexWeeklyPercent: 29)])
        let renderer = ImageRenderer(content: UsageTrendFooter(history: history, now: now)
            .frame(width: 408)
            .padding(16)
            .background(Color.black))
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        #expect(image.size.width == 440)
        if ProcessInfo.processInfo.environment["RESETPLS_RENDER_SELECTOR"] == "1" {
            let tiff = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: "/private/tmp/resetpls-chart-header.png"))
        }
    }
}
