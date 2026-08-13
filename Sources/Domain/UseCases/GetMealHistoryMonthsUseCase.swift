import Foundation

/// Groups logged meals into calendar months for §32's history screen.
///
/// Day boundaries, ordering within a day and month length all belong here rather
/// than to the view model, so the calendar is applied in one place: the totals
/// history shows have to agree with the dashboard's for the same day, and two
/// calendars would eventually disagree.
public struct GetMealHistoryMonthsUseCase: Sendable {
    private let mealRepository: any MealRepository
    private let calendar: Calendar

    public init(mealRepository: any MealRepository, calendar: Calendar = .current) {
        self.mealRepository = mealRepository
        self.calendar = calendar
    }

    /// Months newest first.
    ///
    /// `monthOffset` 0 is the month holding `today`, 1 the month before it, and
    /// so on; `count` months are returned counting back from there. Paging is
    /// expressed as an offset rather than a date so the caller cannot ask for a
    /// month and a `today` that disagree.
    ///
    /// The whole span is **one** repository query. Asking per day would be
    /// 30 round trips to a `@ModelActor` for one screen (§32.5).
    public func execute(
        today: Date,
        monthOffset: Int,
        count: Int
    ) async throws -> [HistoryMonth] {
        guard count > 0, monthOffset >= 0 else { return [] }

        let today = calendar.startOfDay(for: today)
        guard let currentMonth = calendar.dateInterval(of: .month, for: today)?.start else {
            return []
        }

        // Newest first, matching the returned order.
        let monthDays: [[Date]] = (monthOffset..<(monthOffset + count)).compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: -offset, to: currentMonth)
            else { return nil }
            let days = self.days(ofMonthStarting: start, notAfter: today)
            return days.isEmpty ? nil : days
        }

        // The query stops at the end of the last day actually emitted, so a meal
        // dated in the future cannot be counted into a total the grid never
        // draws.
        guard let first = monthDays.last?.first,
            let last = monthDays.first?.last,
            let end = calendar.date(byAdding: .day, value: 1, to: last)
        else { return [] }

        let meals = try await mealRepository.meals(from: first, to: end)
        let byDay = Dictionary(grouping: meals) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.sorted { $0.date < $1.date } }

        return monthDays.compactMap { days in
            guard let start = days.first else { return nil }
            let parts = calendar.dateComponents([.year, .month], from: start)
            return HistoryMonth(
                year: parts.year ?? 0,
                month: parts.month ?? 0,
                // Only days with something on them, newest first. The month is
                // still returned when that leaves nothing, because paging counts
                // months and the caller has to know how far back it has read.
                days: days.reversed().compactMap { date in
                    guard let meals = byDay[date] else { return nil }
                    return HistoryDay(date: date, meals: meals)
                }
            )
        }
    }

    /// Every day of the month `start` opens, dropped once past `notAfter`.
    ///
    /// Built by adding days to the first of the month rather than by arithmetic
    /// on seconds: a day is not 86,400 seconds long in a zone that observes DST,
    /// and Vietnam not observing it is not a reason to get this wrong.
    private func days(ofMonthStarting start: Date, notAfter cutoff: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        var days: [Date] = []
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else {
                continue
            }
            let startOfDay = calendar.startOfDay(for: date)
            if startOfDay > cutoff { break }
            days.append(startOfDay)
        }
        return days
    }

}
