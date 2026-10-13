import AIUsageCore
import Foundation
import Testing

struct SettingsClarityTests {
    @Test func tokenStatesDistinguishOptionalSetupAndActualFailures() {
        #expect(LocalTokenHistoryState.resolve(hasStoredAccess: false, hasUsableAccess: false,
            hasTotals: false, readStatus: .unknown) == .notEnabled)
        #expect(LocalTokenHistoryState.resolve(hasStoredAccess: true, hasUsableAccess: false,
            hasTotals: true, readStatus: .ready) == .accessLost)
        #expect(LocalTokenHistoryState.resolve(hasStoredAccess: true, hasUsableAccess: true,
            hasTotals: true, readStatus: .failed) == .readFailed)
        #expect(LocalTokenHistoryState.resolve(hasStoredAccess: true, hasUsableAccess: true,
            hasTotals: false, readStatus: .ready) == .noActivity)
        #expect(LocalTokenHistoryState.resolve(hasStoredAccess: true, hasUsableAccess: true,
            hasTotals: false, readStatus: .unknown) == .awaitingRead)
        #expect(LocalTokenHistoryState.resolve(hasStoredAccess: true, hasUsableAccess: true,
            hasTotals: true, readStatus: .reading) == .checking)
        #expect(LocalTokenHistoryState.resolve(hasStoredAccess: true, hasUsableAccess: true,
            hasTotals: true, readStatus: .ready) == .enabled)
    }

    @Test func optionalHistoryDoesNotCreateAnErrorAndActionsMatchState() {
        #expect(!LocalTokenHistoryState.notEnabled.needsAttention)
        #expect(!LocalTokenHistoryState.noActivity.needsAttention)
        #expect(!LocalTokenHistoryState.enabled.needsAttention)
        #expect(LocalTokenHistoryState.accessLost.needsAttention)
        #expect(LocalTokenHistoryState.readFailed.needsAttention)
        #expect(LocalTokenHistoryState.enabled.actionTitle(language: .spanish) == "Cambiar carpeta…")
        #expect(LocalTokenHistoryState.notEnabled.actionTitle(language: .english) == "Enable…")
        #expect(LocalTokenHistoryState.readFailed.actionTitle(language: .spanish) == "Reintentar")
        for language in AppLanguage.allCases {
            #expect(!LocalTokenHistoryState.noActivity.help(language: language).contains("Restore access"))
            #expect(!LocalTokenHistoryState.noActivity.help(language: language).contains("Restablece"))
        }
    }

    @Test func savedReadingsIncludeDateOnlyAfterMoreThanTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(!UsageObservationFormatter.includesDate(observedAt: now.addingTimeInterval(-86_400), now: now))
        #expect(UsageObservationFormatter.includesDate(observedAt: now.addingTimeInterval(-86_401), now: now))
        #expect(!UsageObservationFormatter.includesDate(observedAt: now.addingTimeInterval(1), now: now))
        for language in AppLanguage.allCases {
            let old = now.addingTimeInterval(-4 * 86_400)
            let timeOnly = old.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(language.locale))
            #expect(UsageObservationFormatter.string(observedAt: old, now: now, language: language) != timeOnly)
            #expect(!UsageObservationFormatter.compact(observedAt: old, now: now, language: language).isEmpty)
        }
    }
}
