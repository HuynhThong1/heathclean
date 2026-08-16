import Foundation

/// Dates written in the language the app is drawn in.
///
/// Most of this is ICU doing the work: a localized *template* ("EEEE d M")
/// asks for weekday-day-month and lets each locale order and punctuate it, so
/// `vi_VN` answers "Thứ Năm, 13/8" and `en_US` answers "Thursday, 8/13" from one
/// line. That is why the old hand-built strings are gone — they were
/// concatenation that only ever had one right answer.
///
/// **Three of them still branch on the language, and each for its own reason** —
/// see the comments below. The rule is: ICU decides *format*, the design decides
/// *copy*, and where the handoff wrote the Vietnamese words itself, those words
/// win.
///
/// `@MainActor` for the reason `AppNumber` is: non-Sendable formatters held in a
/// cache, and every caller is a view.
@MainActor
enum AppDate {
    private static var language: ResolvedLanguage { AppLanguage.current.resolved }

    /// Gregorian and pinned to the device time zone. The locale only steers the
    /// symbols a formatter reads out of it; day boundaries are
    /// `HistoryCalendar`'s job and are deliberately **not** locale-dependent.
    private static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = language.locale
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    /// Formatters are expensive to build and these run once per row per render,
    /// so they are cached per (template, language).
    private static var templated: [String: DateFormatter] = [:]

    private static func formatter(template: String) -> DateFormatter {
        let language = language
        let key = "\(language.rawValue)|\(template)"
        if let cached = templated[key] { return cached }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        templated[key] = formatter
        return formatter
    }

    /// `vi_VN` opens a weekday lower case ("thứ năm") where the design draws it
    /// capitalized, and English is capitalized already — so this is a no-op in
    /// one language rather than a rule for it.
    private static func capitalizingFirst(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "Thứ Bảy, 9/8" / "Saturday, 8/9" — weekday then day/month, per §6.4.
    static func headerText(for date: Date) -> String {
        capitalizingFirst(formatter(template: "EEEE d M").string(from: date))
    }

    /// Day of month, zero-padded so a column of dates keeps one width.
    ///
    /// Not `AppNumber`: that exists for figures a grouping separator applies to,
    /// and a day of month is never one. Locale-independent for the same reason.
    static func dayNumber(for date: Date) -> String {
        String(format: "%02d", calendar().component(.day, from: date))
    }

    /// "Th 5" / "CN" / "Thu" — the weekday under a history day card's date
    /// (HISTORY_SPEC §4).
    ///
    /// **Vietnamese is written here rather than taken from ICU**, which offers
    /// "Thứ 5" (too wide for the 42pt column) and "T5" (reads like a code in a
    /// column of its own). "Th 5" is the middle the spec asked for and neither
    /// symbol set has it. English has no such problem — "Thu" is exactly
    /// `shortWeekdaySymbols`.
    static func weekdayCompact(for date: Date) -> String {
        let weekday = calendar().component(.weekday, from: date)
        switch language {
        case .vietnamese:
            return weekday == 1 ? "CN" : "Th \(weekday)"
        case .english:
            let formatter = DateFormatter()
            formatter.locale = language.locale
            return formatter.shortWeekdaySymbols[weekday - 1]
        }
    }

    /// "T2" / "Mon" — the narrowest weekday, for §6.12's seven-column bar chart.
    ///
    /// Narrower than `weekdayCompact` on purpose: that one has a 42pt column to
    /// itself and can afford "Th 5", this one has a seventh of the screen.
    ///
    /// **It cannot go through the catalog**, which is the interesting part: the
    /// Vietnamese is "T2", and "T%lld" is already a key — the *weight* chart's
    /// week label, "W%lld" in English. One string, two meanings, and translating
    /// the shared key would have put "W2" under a Monday.
    static func weekdayNarrow(for date: Date) -> String {
        let weekday = calendar().component(.weekday, from: date)
        switch language {
        case .vietnamese:
            return weekday == 1 ? "CN" : "T\(weekday)"
        case .english:
            let formatter = DateFormatter()
            formatter.locale = language.locale
            return formatter.shortWeekdaySymbols[weekday - 1]
        }
    }

    /// "Thứ Năm" / "Thursday" — spelled out, for VoiceOver and for the day
    /// panel's title.
    static func weekdayFull(for date: Date) -> String {
        capitalizingFirst(formatter(template: "EEEE").string(from: date))
    }

    /// "13/8" / "8/13" — the date on a search result (HISTORY_SPEC §8).
    ///
    /// Vietnamese keeps its zero-padded day so a column of results holds one
    /// width; English takes ICU's order, where the month leads and padding the
    /// day would pad the wrong end.
    static func dayMonth(for date: Date) -> String {
        switch language {
        case .vietnamese:
            let parts = calendar().dateComponents([.day, .month], from: date)
            return String(format: "%02d/%d", parts.day ?? 0, parts.month ?? 0)
        case .english:
            return formatter(template: "dM").string(from: date)
        }
    }

    /// "Thứ Năm, 13/8/2026" / "Thursday, 8/13/2026" — the day panel's title
    /// (HISTORY_SPEC §8).
    static func fullDayText(for date: Date) -> String {
        capitalizingFirst(formatter(template: "EEEEdMy").string(from: date))
    }

    /// "Thứ Năm, 13 tháng 8" / "Thursday, August 13" — the same day read aloud.
    /// §7's day-card label opens with this, so "13/8" is never spoken as a
    /// fraction.
    static func spokenDayText(for date: Date) -> String {
        capitalizingFirst(formatter(template: "EEEEdMMMM").string(from: date))
    }

    /// "06:50" / "6:50 AM" — the time column of the day panel's meal list.
    static func time(for date: Date) -> String {
        let language = language
        let key = "\(language.rawValue)|shortTime"
        if let cached = templated[key] { return cached.string(from: date) }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        templated[key] = formatter
        return formatter.string(from: date)
    }

    /// "Tháng 8, 2026" / "August 2026" from the numbers a `HistoryMonth` carries,
    /// with no date to format — which is what an *empty* month has
    /// (HISTORY_SPEC §6).
    ///
    /// **The Vietnamese is the spec's wording, not ICU's.** `yMMMM` under
    /// `vi_VN` gives "tháng 8 năm 2026", which is good Vietnamese and is not what
    /// HISTORY_SPEC §6 draws in the month header.
    static func monthYearText(year: Int, month: Int) -> String {
        switch language {
        case .vietnamese:
            return "Tháng \(month), \(year)"
        case .english:
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            guard let date = calendar().date(from: components) else {
                return "\(month)/\(year)"
            }
            return formatter(template: "yMMMM").string(from: date)
        }
    }
}
