import AIUsageCore
import Foundation
import Testing

struct UsageHistoryProtectionTests {
    private func fixture() throws -> (URL, UsageHistoryCache, Date, Data) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("history-protection-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("usage-history.json")
        let day = Calendar.current.startOfDay(for: .now).addingTimeInterval(-86_400)
        // Deliberately unversioned: exactly the format shipped before protection.
        let original = try JSONEncoder().encode(UsageHistory(days: [UsageHistoryDay(
            date: day, claudePercent: 90, codexPercent: 35, claudeTokens: 120,
            claudeWeeklyPercent: 23, codexWeeklyPercent: 35,
            claudeWeeklyObservedAt: day.addingTimeInterval(600),
            codexWeeklyObservedAt: day.addingTimeInterval(700)
        )]))
        try original.write(to: file)
        return (folder, UsageHistoryCache(fileURL: file), day, original)
    }

    @Test func updatingLegacyHistoryPreservesWeeklyBalancesAndExactRecoveryCopy() throws {
        let (folder, cache, day, original) = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = day.addingTimeInterval(90_000)
        let reading = ProviderUsageSnapshot(id: .claude,
            session: UsageWindow(usedPercent: 10, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 24, resetsAt: nil),
            observedAt: now, source: .live, message: nil)
        _ = try cache.recording([reading], at: now)
        _ = try cache.applyingDailyTokens([.claude: [day: 130]], periodStart: day, periodEnd: now)
        let history = try cache.applyingActivityDates([day], periodStart: day, periodEnd: now)
        let previous = try #require(history.days.first { $0.date == day })
        #expect(previous.claudeWeeklyPercent == 23)
        #expect(previous.codexWeeklyPercent == 35)
        #expect(previous.claudeWeeklyObservedAt == day.addingTimeInterval(600))
        #expect(previous.codexWeeklyObservedAt == day.addingTimeInterval(700))
        #expect(previous.claudeTokens == 130)
        #expect(history.days.last?.claudeWeeklyPercent == 24)
        let backups = try FileManager.default.contentsOfDirectory(at: cache.backupDirectoryURL, includingPropertiesForKeys: nil)
        #expect(backups.count == 2)
        for backup in backups { #expect(try Data(contentsOf: backup) == original) }
        // Every emitted document remains readable by the current model.
        #expect(cache.load() == history)
    }

    @Test func damagedOrFutureFilesRemainByteForByteIntactForEveryWriter() throws {
        let (folder, cache, day, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let date = day.timeIntervalSinceReferenceDate
        let inputs = [
            "{broken", "{\"days\":null}",
            "{\"schemaVersion\":2,\"days\":[]}",
            "{\"schemaVersion\":true,\"days\":[]}",
            "{\"days\":[],\"futureQuota\":42}",
            "{\"days\":[{\"date\":\(date),\"claudeWeeklyPercent\":23,\"futureBalance\":18}]}",
            "{\"days\":[{\"date\":\(date)},{\"date\":\(date)}]}"
        ]
        for input in inputs {
            let bytes = Data(input.utf8)
            try bytes.write(to: cache.fileURL)
            #expect(throws: (any Error).self) { try cache.recording([], at: day) }
            #expect(throws: (any Error).self) { try cache.applyingDailyTokens([:], periodStart: day, periodEnd: day) }
            #expect(throws: (any Error).self) { try cache.applyingActivityDates([], periodStart: day, periodEnd: day) }
            #expect(try Data(contentsOf: cache.fileURL) == bytes)
            #expect(!FileManager.default.fileExists(atPath: cache.backupDirectoryURL.path))
        }
    }

    @Test func backupFailurePreventsOverwritingThePrimaryHistory() throws {
        let (folder, cache, day, original) = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        // A file blocking the directory simulates an unavailable backup destination.
        try Data("blocked".utf8).write(to: cache.backupDirectoryURL)
        #expect(throws: (any Error).self) { try cache.recording([], at: day) }
        #expect(try Data(contentsOf: cache.fileURL) == original)
    }

    @Test func rotationRetainsSevenDailyCopiesAndTheOriginalBaseline() throws {
        let (folder, cache, day, original) = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        _ = try cache.recording([], at: day)
        for index in 1...10 {
            let name = String(format: "daily-2000-01-%02d.json", index)
            try original.write(to: cache.backupDirectoryURL.appendingPathComponent(name))
        }
        _ = try cache.recording([], at: day)
        let backups = try FileManager.default.contentsOfDirectory(at: cache.backupDirectoryURL, includingPropertiesForKeys: nil)
        #expect(backups.filter { $0.lastPathComponent.hasPrefix("daily-") }.count == 7)
        #expect(try Data(contentsOf: cache.backupDirectoryURL.appendingPathComponent("before-protection-v1.json")) == original)
    }

    @Test func emptyOrMissingPrimaryDoesNotReplaceRecoveryCopies() throws {
        let (folder, cache, day, original) = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        _ = try cache.recording([], at: day)
        let baseline = cache.backupDirectoryURL.appendingPathComponent("before-protection-v1.json")
        try Data("{\"days\":[]}".utf8).write(to: cache.fileURL)
        _ = try cache.recording([], at: day)
        #expect(try Data(contentsOf: baseline) == original)
        try FileManager.default.removeItem(at: cache.fileURL)
        #expect(throws: (any Error).self) { try cache.recording([], at: day) }
        #expect(!FileManager.default.fileExists(atPath: cache.fileURL.path))
        #expect(try Data(contentsOf: baseline) == original)
    }

    @Test func freshInstallCreatesHistoryNormally() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("new-history-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = UsageHistoryCache(fileURL: folder.appendingPathComponent("usage-history.json"))
        let result = try cache.recording([], at: .now)
        #expect(result.days.count == 1)
        #expect(cache.load() == result)
    }
}
