import Foundation

/// The calendar history shares with the dashboard, and the day identifier the
/// list labels its cards with.
///
/// It lives outside the view model because `DependencyContainer` builds
/// `GetMealHistoryMonthsUseCase` with it: history's day boundaries have to be
/// the dashboard's, or a 23:30 meal lands on different days in different places.
enum HistoryCalendar {
    /// Monday-first, and **deliberately independent of the app's language**.
    ///
    /// It used to take Monday from a `vi_VN` locale. That was the same answer by
    /// accident: `en_US` starts the week on Sunday, so once the UI can be drawn
    /// in English a locale-derived calendar would silently move every week
    /// boundary — and these boundaries are shared with the dashboard through
    /// `GetMealHistoryMonthsUseCase`, so a 23:30 meal would land on a different
    /// week depending on a display preference. `firstWeekday` is set outright
    /// and no locale is attached.
    ///
    /// The persisted meal dates use the civil Gregorian calendar. Do not inherit
    /// an alternate system calendar from Settings either: it would make the
    /// numeric month disagree with `AppDate`, whose formatters are Gregorian.
    static func mondayFirst() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    /// A stable, locale-independent `yyyy-MM-dd` so a UI test can name a day.
    ///
    /// Built from date components rather than a `DateFormatter`: this runs once
    /// per card per render and a formatter is expensive to construct, which it
    /// would have to be every time, being neither `Sendable` nor cacheable in a
    /// `static let` under strict concurrency.
    static func identifier(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
