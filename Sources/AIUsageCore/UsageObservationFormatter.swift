import Foundation

public enum UsageObservationFormatter {
    public static func includesDate(observedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(observedAt) > 86_400
    }

    public static func string(observedAt: Date, now: Date, language: AppLanguage) -> String {
        if includesDate(observedAt: observedAt, now: now) {
            return observedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(language.locale))
        }
        return observedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(language.locale))
    }

    public static func compact(observedAt: Date, now: Date, language: AppLanguage) -> String {
        if includesDate(observedAt: observedAt, now: now) {
            return observedAt.formatted(.dateTime.day().month(.twoDigits).locale(language.locale))
        }
        return string(observedAt: observedAt, now: now, language: language)
    }
}
