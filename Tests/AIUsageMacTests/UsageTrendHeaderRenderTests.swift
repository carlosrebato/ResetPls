import AIUsageCore
import AIUsageDesignSystem
import AppKit
import SwiftUI
import Testing

struct UsageTrendHeaderRenderTests {
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
