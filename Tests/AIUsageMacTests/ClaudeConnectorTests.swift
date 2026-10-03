import Foundation
import Testing
import AIUsageCore
@testable import AIUsageMacServices

struct ClaudeConnectorTests {
    @Test func recentStatuslineCanActAsFallback() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("limits.json")
        let observedAt = Date.now
        let payload = #"{"sessionPercent":18,"weekPercent":37,"resetAt":"2026-07-22T12:00:00Z","weekResetAt":"2026-07-27T00:00:00Z","lastUpdated":"2026-07-22T08:00:00Z"}"#
        try Data(payload.utf8).write(to: file)

        let snapshot = ClaudeStatuslineReader(fileURL: file).readFresh(now: observedAt)
        #expect(snapshot?.session.usedPercent == 18)
        #expect(snapshot?.weekly.usedPercent == 37)
        #expect(snapshot?.source == .cached)
    }

    @Test func staleStatuslineIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("limits.json")
        try Data(#"{"sessionPercent":18,"weekPercent":37}"#.utf8).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: Date.now.addingTimeInterval(-3600)],
            ofItemAtPath: file.path
        )

        #expect(ClaudeStatuslineReader(fileURL: file, maximumAge: 600).readFresh(now: .now) == nil)
    }
}
