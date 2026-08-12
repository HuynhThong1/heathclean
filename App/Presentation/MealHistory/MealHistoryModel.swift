import Domain
import Foundation

/// Monday-first, so the week strip's first column is T2. `Calendar.current`
/// starts the week on Sunday under a US locale, which would put CN first while
/// the labels underneath still read T2…CN.
private func weekCalendar() -> Calendar {
    // The Vietnamese UI and persisted meal dates use the civil Gregorian
    // calendar. Do not inherit an alternate system calendar from Settings: it
    // would make the numeric month in the strip disagree with `dayText`, whose
    // `vi_VN` formatter is Gregorian.
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "vi_VN")
    calendar.timeZone = .autoupdatingCurrent
    calendar.firstWeekday = 2
    return calendar
}

@MainActor
@Observable
final class MealHistoryModel {
    struct Day: Identifiable {
        let date: Date
        let meals: [Meal]

        var id: Date { date }
        var calories: Double { meals.reduce(0) { $0 + $1.calories } }
    }

    /// One column of the week strip.
    ///
    /// `hasMeals` is what the dot under the number means — a day with nothing
    /// logged gets no dot rather than a hollow one, so the marker is a fact and
    /// not decoration.
    struct DayCell: Identifiable {
        let date: Date
        let hasMeals: Bool
        let isToday: Bool
        /// Nothing can ever be logged here, so the cell is not tappable.
        let isFuture: Bool

        var id: Date { date }
    }

    private(set) var selectedDate: Date
    private(set) var weekStart: Date
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    /// Needed for the per-day progress bar (§6.11); 0 until the profile loads.
    private(set) var dailyGoalCalories: Double = 0

    /// The loaded window, which is exactly the week on screen. Read through
    /// `week` and `selectedDay` — nothing outside needs the raw grouping.
    private var mealsByDay: [Date: [Meal]] = [:]

    private let calendar: Calendar
    private let mealRepository: any MealRepository
    private let userRepository: any UserRepository
    /// Orders overlapping loads, including two requests for the same week.
    private var loadGeneration = 0

    init(mealRepository: any MealRepository, userRepository: any UserRepository) {
        let calendar = weekCalendar()
        let today = calendar.startOfDay(for: Date())
        self.calendar = calendar
        self.selectedDate = today
        self.weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        self.mealRepository = mealRepository
        self.userRepository = userRepository
    }

    var week: [DayCell] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            return DayCell(
                date: date,
                hasMeals: !(mealsByDay[date] ?? []).isEmpty,
                isToday: date == today,
                isFuture: date > today
            )
        }
    }

    var selectedDay: Day {
        Day(date: selectedDate, meals: mealsByDay[selectedDate] ?? [])
    }

    /// False once the week on screen is the one holding today. History is a
    /// record; there is no week ahead of it to page into.
    var canGoForward: Bool {
        let today = calendar.startOfDay(for: Date())
        guard let current = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return false
        }
        return weekStart < current
    }

    /// The meals of one type on one day, for the detail screen. History needs the
    /// day too, where the dashboard only ever asks about today.
    func meals(of type: MealType, on date: Date) -> [Meal] {
        (mealsByDay[calendar.startOfDay(for: date)] ?? []).filter { $0.type == type }
    }

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    func showPreviousWeek() async {
        guard let start = calendar.date(byAdding: .day, value: -7, to: weekStart) else { return }
        await move(toWeekStarting: start)
    }

    func showNextWeek() async {
        guard canGoForward,
              let start = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }
        await move(toWeekStarting: start)
    }

    func load() async {
        // The week that was asked for. Tapping ‹ faster than the store answers
        // starts a second load, and without this the slower of the two could
        // land last and leave the strip's dots describing a week that is no
        // longer on screen.
        let requested = weekStart
        let end = calendar.date(byAdding: .day, value: 7, to: requested) ?? requested
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            let goal = (try await userRepository.load())?.goal.calories ?? 0
            let meals = try await mealRepository.meals(from: requested, to: end)
            guard generation == loadGeneration, requested == weekStart else { return }
            dailyGoalCalories = goal
            mealsByDay = Dictionary(grouping: meals) { calendar.startOfDay(for: $0.date) }
                .mapValues { $0.sorted { $0.date < $1.date } }
            errorMessage = nil
        } catch {
            guard generation == loadGeneration, requested == weekStart else { return }
            errorMessage = String(localized: "Không tải được lịch sử bữa ăn.")
        }
    }

    private func move(toWeekStarting start: Date) async {
        let today = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        weekStart = start
        // Land on today when it is inside the new week, so paging back and
        // forward again returns the screen to where it opened.
        selectedDate = (today >= start && today < end) ? today : start
        await load()
    }
}
