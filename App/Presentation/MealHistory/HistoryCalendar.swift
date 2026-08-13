import Foundation

/// The calendar every history surface shares, and the day identifier both of
/// them label cells with.
///
/// It lives outside the view models because `DependencyContainer` builds
/// `GetMealHistoryMonthsUseCase` with it: the month grid's day boundaries and
/// the week strip's columns have to be the same calendar, or the two disagree
/// about which day a 23:30 meal belongs to.
enum HistoryCalendar {
    /// Monday-first, so the first column is T2. `Calendar.current` starts the
    /// week on Sunday under a US locale, which would put CN first while the
    /// labels underneath still read T2…CN.
    ///
    /// The Vietnamese UI and persisted meal dates use the civil Gregorian
    /// calendar. Do not inherit an alternate system calendar from Settings: it
    /// would make the numeric month disagree with `VietnameseDate`, whose
    /// `vi_VN` formatters are Gregorian.
    static func mondayFirst() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "vi_VN")
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    /// A stable, locale-independent `yyyy-MM-dd` so a UI test can name a day.
    ///
    /// Built from date components rather than a `DateFormatter`: this runs once
    /// per cell per render — up to 31 of them in a month card — and a formatter
    /// is expensive to construct, which it would have to be every time, being
    /// neither `Sendable` nor cacheable in a `static let` under strict
    /// concurrency.
    static func identifier(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// §32 lands in stages, and the month grid *replaces* the week strip rather than
/// sitting beside it (§32.2 item 6). Until it has photo tiles (stage 2) and its
/// finished day sheet (stage 3), the week strip stays the shipping History
/// screen and the grid is reachable only internally.
///
/// Both this flag and the week strip are deleted at stage 4.
enum HistoryFeatureFlags {
    private static let key = "historyTimeline"

    /// **A Debug build is the internal build**, so it opens on the grid — that is
    /// §32.7 stage 4's "bật flag cho nội bộ trước", and it is the only way to try
    /// the grid from the Home Screen, where no launch argument survives. Release
    /// still opens the week strip.
    ///
    /// An explicit value always wins, set from the scheme or the debugger with
    /// `-historyTimeline YES` / `NO`. That is a `UserDefaults` key/value pair
    /// rather than a bare flag like `-uiTesting`, because a bare argument never
    /// reaches `UserDefaults` — hence checking `object(forKey:)` for presence and
    /// `bool(forKey:)` for the value, which is what parses the string "YES".
    ///
    /// The UI suite must not inherit the Debug default: it covers **both**
    /// screens, and three of its tests are about the week strip.
    static var timeline: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) != nil { return defaults.bool(forKey: key) }
        #if DEBUG
            return !ProcessInfo.processInfo.arguments.contains("-uiTesting")
        #else
            return false
        #endif
    }
}
