import Domain
import Foundation

/// State for §32's month grid: which months are loaded, which day is open, and
/// whether there is anything older to page into.
///
/// Everything about *what a month contains* belongs to
/// `GetMealHistoryMonthsUseCase`. This holds paging, selection and the
/// loading/error states, per §32.5.
@MainActor
@Observable
final class HistoryMonthsModel {
    /// The opening window: the current month plus two behind it (§32.3).
    static let initialMonthCount = 3
    /// One page of "older", asked for as the footer comes into view.
    static let pageMonthCount = 3
    /// How many pages one request may chase through empty months — 18 months of
    /// nothing before it gives up and lets the user ask again.
    static let maxPagesPerRequest = 6

    /// Every month read so far, empty ones included — paging counts months, so
    /// the count has to include the ones with nothing in them. Read `visibleMonths`
    /// for what the screen draws.
    private(set) var months: [HistoryMonth] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    /// Needed for the per-day progress bar; 0 until the profile loads.
    private(set) var dailyGoalCalories: Double = 0
    /// False once the oldest logged meal's month is on screen. The store can
    /// always answer for one more month — an empty one — so this is a fact about
    /// the data rather than about the query.
    private(set) var canLoadMore = false
    /// The day whose sheet is open, if any.
    private(set) var selectedDate: Date?

    private let calendar: Calendar
    private let getMonths: GetMealHistoryMonthsUseCase
    private let mealRepository: any MealRepository
    private let userRepository: any UserRepository
    /// Orders overlapping loads. Two pages can be in flight at once and nothing
    /// orders two `@ModelActor` calls, so the slower one landing last would
    /// otherwise leave the grid describing a window it was not asked for — the
    /// case the week strip already hit.
    private var loadGeneration = 0
    private var earliestMealDate: Date?
    /// How far back the reads have gone. Not `months.count`: they agree today, but
    /// tying paging to the array would break the moment an empty month stopped
    /// being kept.
    private var loadedMonthCount = 0

    init(
        getMonths: GetMealHistoryMonthsUseCase,
        mealRepository: any MealRepository,
        userRepository: any UserRepository,
        calendar: Calendar = HistoryCalendar.mondayFirst()
    ) {
        self.getMonths = getMonths
        self.mealRepository = mealRepository
        self.userRepository = userRepository
        self.calendar = calendar
    }

    /// Recomputed rather than stored: the screen can be left open across
    /// midnight, and a grid whose "today" is yesterday marks the wrong cell.
    var today: Date { calendar.startOfDay(for: Date()) }

    var isEmpty: Bool { earliestMealDate == nil }

    /// What the screen draws: months that have something in them. A month with
    /// nothing logged is not a section of dots any more — it simply is not there.
    var visibleMonths: [HistoryMonth] { months.filter(\.hasMeals) }

    var selectedDay: HistoryDay? {
        guard let selectedDate else { return nil }
        for month in months {
            if let day = month.days.first(where: { $0.date == selectedDate }) {
                return day
            }
        }
        return nil
    }

    func select(_ day: HistoryDay) {
        selectedDate = day.date
    }

    func clearSelection() {
        selectedDate = nil
    }

    /// First load, and every refresh after an edit.
    ///
    /// A refresh re-reads as many months as are already open rather than
    /// dropping back to three, so returning from a meal detail does not throw
    /// away the pages the user scrolled to (§32.3).
    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        // Only the first load blanks the screen; a refresh keeps the grid up so
        // the scroll position survives it.
        let isFirstLoad = months.isEmpty
        if isFirstLoad { isLoading = true }
        defer {
            if generation == loadGeneration { isLoading = false }
        }

        let today = self.today
        let wanted = max(Self.initialMonthCount, loadedMonthCount)

        do {
            let goal = (try await userRepository.load())?.goal.calories ?? 0
            let earliest = try await mealRepository.earliestMealDate()
            let page = try await getMonths.execute(today: today, monthOffset: 0, count: wanted)
            guard generation == loadGeneration else { return }
            dailyGoalCalories = goal
            earliestMealDate = earliest
            months = page
            loadedMonthCount = wanted
            updateCanLoadMore(today: today)
            errorMessage = nil
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = String(localized: "Không tải được lịch sử bữa ăn.")
        }
    }

    /// The next page of older months. Safe to call from an `onAppear`: it is a
    /// no-op while a page is in flight or once the oldest meal is on screen.
    ///
    /// **It keeps reading until something appears.** Now that empty months are not
    /// drawn, one page of three can add nothing to the screen — and a "load more"
    /// that visibly does nothing reads as broken. Bounded, because the floor is
    /// `canLoadMore` rather than a guess.
    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        let generation = loadGeneration
        let today = self.today
        isLoadingMore = true
        defer {
            if generation == loadGeneration { isLoadingMore = false }
        }

        for _ in 0..<Self.maxPagesPerRequest {
            let offset = loadedMonthCount
            do {
                let page = try await getMonths.execute(
                    today: today,
                    monthOffset: offset,
                    count: Self.pageMonthCount
                )
                // A refresh that landed while this page was in flight has already
                // rebuilt `months` from the start; appending to it now would
                // duplicate whatever it re-read.
                guard generation == loadGeneration, loadedMonthCount == offset else { return }
                months += page
                loadedMonthCount += Self.pageMonthCount
                updateCanLoadMore(today: today)
                if page.contains(where: \.hasMeals) || !canLoadMore { return }
            } catch {
                guard generation == loadGeneration else { return }
                errorMessage = String(localized: "Không tải được lịch sử bữa ăn.")
                return
            }
        }
    }

    /// How many months lie between the oldest logged meal and today, inclusive
    /// of both ends — the total the grid can ever show.
    private func updateCanLoadMore(today: Date) {
        guard let earliestMealDate,
            let earliestMonth = calendar.dateInterval(of: .month, for: earliestMealDate)?.start,
            let currentMonth = calendar.dateInterval(of: .month, for: today)?.start,
            let span = calendar.dateComponents([.month], from: earliestMonth, to: currentMonth).month
        else {
            canLoadMore = false
            return
        }
        canLoadMore = loadedMonthCount < span + 1
    }
}
