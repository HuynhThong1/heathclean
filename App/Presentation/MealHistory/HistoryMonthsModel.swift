import Domain
import Foundation

/// What the history scroll draws, in order: a month with days in it, or one line
/// standing in for a month with none (HISTORY_SPEC §1, §6).
///
/// The two cases exist because paging counts *months* while the screen shows *days*.
/// An empty month has to be visible — skipping it silently would make a run of dates
/// read as continuous when a whole month is missing from it — but it must not be a
/// section of empty cells, which is §0.1.
enum HistoryFeedItem: Identifiable {
    case month(HistoryMonth)
    case emptyMonth(year: Int, month: Int)

    var id: String {
        switch self {
        case .month(let month): "month-\(month.id)"
        case .emptyMonth(let year, let month): "empty-\(String(format: "%04d-%02d", year, month))"
        }
    }
}

/// State for the history screen: which months are loaded, which day is open, what
/// the search box and the filter chips are set to, and whether there is anything
/// older to page into.
///
/// Everything about *what a month contains* belongs to
/// `GetMealHistoryMonthsUseCase`. This holds paging, selection, filtering and the
/// loading/error states, per §1's state machine.
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
    /// §5: long enough that the list does not thrash while a word is being typed,
    /// short enough that it never feels like a submit.
    static let searchDebounce = Duration.milliseconds(250)

    /// Every month read so far, empty ones included — paging counts months, so
    /// the count has to include the ones with nothing in them. Read `feed` for
    /// what the screen draws.
    private(set) var months: [HistoryMonth] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    /// The whole day's targets: calories for the bars, macros for the day panel.
    /// `nil` until the profile loads.
    private(set) var goal: NutritionGoal?
    /// False once the oldest logged meal's month is on screen. The store can
    /// always answer for one more month — an empty one — so this is a fact about
    /// the data rather than about the query.
    private(set) var canLoadMore = false
    /// "Tháng 3, 2026" while a page is in flight, for §6's pagination copy.
    private(set) var loadingMonthLabel: String?
    /// The day whose panel is open, if any.
    private(set) var selectedDate: Date?

    /// What is in the search box, keystroke by keystroke. Bound by the view but
    /// written through `updateSearch(_:)`, which is what starts the debounce.
    private(set) var searchText = ""
    /// The keyword actually being filtered on — `searchText` 250 ms ago, and empty
    /// below §5's two-character floor.
    private(set) var activeQuery = ""
    private(set) var filters: Set<HistoryFilter> = []
    /// True while a keystroke is waiting out the debounce. §5 asks for no spinner:
    /// the previous list stays, dimmed, so the screen never blanks mid-word.
    private(set) var isFiltering = false
    private(set) var results: [HistoryMealHit] = []

    private let calendar: Calendar
    private let getMonths: GetMealHistoryMonthsUseCase
    private let mealRepository: any MealRepository
    private let userRepository: any UserRepository
    /// Orders overlapping loads. Two pages can be in flight at once and nothing
    /// orders two `@ModelActor` calls, so the slower one landing last would
    /// otherwise leave the list describing a window it was not asked for.
    private var loadGeneration = 0
    private var earliestMealDate: Date?
    /// How far back the reads have gone. Not `months.count`: they agree today, but
    /// tying paging to the array would break the moment an empty month stopped
    /// being kept.
    private var loadedMonthCount = 0
    private var filterTask: Task<Void, Never>?

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
    /// midnight, and a list whose "today" is yesterday marks the wrong card.
    var today: Date { calendar.startOfDay(for: Date()) }

    var isEmpty: Bool { earliestMealDate == nil }

    /// The **current** target, which is only what a day falls back to.
    ///
    /// §8 asks for the target that was in force on the day itself, and that now
    /// comes from the day: `Meal.calorieGoalWhenLogged` is stamped at save time and
    /// `HistoryDay.goalCalories` reads it, so changing the goal no longer moves
    /// every past day's bar. This figure is what a day with no stamp on it uses —
    /// meals logged before the field existed — and it is also the day panel's source
    /// for the macro targets, which are not recorded per day.
    var dailyGoalCalories: Double { goal?.calories ?? 0 }

    /// The months and dividers the scroll draws (§1).
    ///
    /// Empty months **older than the first logged meal** are dropped: they are not
    /// gaps in the record, they are time before there was a record, and a divider
    /// for each would be an apology for months the user was not using the app.
    var feed: [HistoryFeedItem] {
        months.compactMap { month in
            if month.hasMeals { return .month(month) }
            guard isWithinRecord(year: month.year, month: month.month) else { return nil }
            return .emptyMonth(year: month.year, month: month.month)
        }
    }

    /// Whether the screen shows meals instead of days (§5). A keyword under two
    /// characters does not count — §5 says it does not filter, and switching the
    /// unit of the list to show *everything* by meal would be a worse answer to one
    /// letter than leaving the list alone.
    var isSearchActive: Bool {
        activeQuery.count >= HistorySearchText.minimumQueryLength || !filters.isEmpty
    }

    /// "4 bữa có “phở” · 3 tháng gần nhất" (§5).
    var resultsHeader: String {
        let count = results.count
        let months = String(localized: "\(loadedMonthCount) tháng gần nhất")
        guard !activeQuery.isEmpty else {
            return String(localized: "\(count) bữa · \(months)")
        }
        return String(localized: "\(count) bữa có “\(activeQuery)” · \(months)")
    }

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

    /// Opens the day a search hit belongs to. §4 puts one way into a meal — the day
    /// panel — and a result list that pushed straight to a meal detail would be a
    /// second, with its own copy of the delete and refresh plumbing.
    func selectDay(of hit: HistoryMealHit) {
        selectedDate = hit.dayDate
    }

    func clearSelection() {
        selectedDate = nil
    }

    // MARK: Search and filters

    /// Every keystroke. The query itself only moves 250 ms later (§5).
    func updateSearch(_ text: String) {
        searchText = text
        scheduleFilter()
    }

    /// Chips apply at once: a tap is a decision, where a keystroke is half of one.
    func toggle(_ filter: HistoryFilter) {
        if filter == .all {
            filters.removeAll()
        } else if filters.contains(filter) {
            filters.remove(filter)
        } else {
            filters.insert(filter)
        }
        rebuildResults()
    }

    /// §6's "Xoá bộ lọc" — the keyword and the chips together, because either one
    /// alone can be why nothing was found.
    func clearSearch() {
        filterTask?.cancel()
        filterTask = nil
        searchText = ""
        activeQuery = ""
        filters.removeAll()
        isFiltering = false
        rebuildResults()
    }

    private func scheduleFilter() {
        filterTask?.cancel()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Below the floor there is nothing to wait for: dropping back to the day
        // list has to feel like undoing the search, not like another 250 ms of it.
        guard trimmed.count >= HistorySearchText.minimumQueryLength else {
            isFiltering = false
            activeQuery = ""
            rebuildResults()
            return
        }

        isFiltering = true
        filterTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDebounce)
            guard !Task.isCancelled else { return }
            self?.commit(query: trimmed)
        }
    }

    private func commit(query: String) {
        activeQuery = query
        isFiltering = false
        rebuildResults()
    }

    /// Filters the meals of every loaded month (§5 — the scope is what has been
    /// paged in, which is why the footer says so).
    ///
    /// Plain iteration over what is already in memory: a `@ModelActor` query per
    /// keystroke would be the obvious alternative and is the wrong one, because the
    /// scope of a search here is exactly "what the screen has", and a store query
    /// would quietly widen it to months the list does not show.
    private func rebuildResults() {
        guard isSearchActive else {
            results = []
            return
        }

        let foldedQuery =
            activeQuery.count >= HistorySearchText.minimumQueryLength
            ? HistorySearchText.folded(activeQuery) : nil
        let wantedTypes = Set(filters.compactMap(\.mealType))
        let fallbackGoal = dailyGoalCalories

        var hits: [HistoryMealHit] = []
        for month in months {
            for day in month.days {
                // §5's groups: `overBudget` is a property of the day, the meal chips
                // of the meal, and the two are ANDed.
                //
                // Against *that day's* target, the same figure its card draws — a
                // filter that disagreed with the bar beside it would be worse than
                // no filter.
                if filters.contains(.overBudget) {
                    let goalCalories = day.goalCalories(fallingBackTo: fallbackGoal)
                    guard goalCalories > 0, day.calories > goalCalories else { continue }
                }
                for meal in day.meals {
                    if filters.contains(.hasPhoto), meal.photos.isEmpty { continue }
                    if !wantedTypes.isEmpty, !wantedTypes.contains(meal.type) { continue }
                    guard let foldedQuery else {
                        hits.append(hit(meal, on: day.date, title: nil))
                        continue
                    }
                    let matched = meal.items.filter {
                        HistorySearchText.contains(foldedQuery: foldedQuery, in: $0.name)
                    }
                    if !matched.isEmpty {
                        hits.append(
                            hit(meal, on: day.date, title: matched.map(\.name).joined(separator: ", "))
                        )
                    } else if HistorySearchText.contains(
                        foldedQuery: foldedQuery, in: meal.type.vi
                    ) {
                        // §5's scope is the dish *and* the meal's name, so "sáng"
                        // finds every breakfast.
                        hits.append(hit(meal, on: day.date, title: nil))
                    }
                }
            }
        }
        results = hits.sorted { $0.meal.date > $1.meal.date }
    }

    private func hit(_ meal: Meal, on date: Date, title: String?) -> HistoryMealHit {
        HistoryMealHit(
            meal: meal,
            dayDate: date,
            title: title ?? HistoryDayCard.chipName(for: meal)
        )
    }

    // MARK: Loading

    /// First load, and every refresh after an edit.
    ///
    /// A refresh re-reads as many months as are already open rather than
    /// dropping back to three, so returning from a meal detail does not throw
    /// away the pages the user scrolled to (§32.3).
    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        // Only the first load blanks the screen; a refresh keeps the list up so
        // the scroll position survives it.
        let isFirstLoad = months.isEmpty
        if isFirstLoad { isLoading = true }
        defer {
            if generation == loadGeneration { isLoading = false }
        }

        let today = self.today
        let wanted = max(Self.initialMonthCount, loadedMonthCount)

        do {
            let goal = try await userRepository.load()?.goal
            let earliest = try await mealRepository.earliestMealDate()
            let page = try await getMonths.execute(today: today, monthOffset: 0, count: wanted)
            guard generation == loadGeneration else { return }
            self.goal = goal
            earliestMealDate = earliest
            months = page
            loadedMonthCount = wanted
            updateCanLoadMore(today: today)
            errorMessage = nil
            // A refresh can have removed the meal a hit pointed at.
            rebuildResults()
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = String(localized: "Không đọc được dữ liệu")
        }
    }

    /// The next page of older months. Safe to call from an `onAppear`: it is a
    /// no-op while a page is in flight or once the oldest meal is on screen.
    ///
    /// **It keeps reading until something appears.** Now that empty months are not
    /// drawn as sections, one page of three can add nothing to the screen — and a
    /// "load more" that visibly does nothing reads as broken. Bounded, because the
    /// floor is `canLoadMore` rather than a guess.
    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        let generation = loadGeneration
        let today = self.today
        isLoadingMore = true
        loadingMonthLabel = monthLabel(offset: loadedMonthCount, today: today)
        defer {
            if generation == loadGeneration {
                isLoadingMore = false
                loadingMonthLabel = nil
            }
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
                // A search is scoped to the loaded months, so a new page widens it.
                rebuildResults()
                if page.contains(where: \.hasMeals) || !canLoadMore { return }
                loadingMonthLabel = monthLabel(offset: loadedMonthCount, today: today)
            } catch {
                guard generation == loadGeneration else { return }
                errorMessage = String(localized: "Không đọc được dữ liệu")
                return
            }
        }
    }

    /// How many months lie between the oldest logged meal and today, inclusive
    /// of both ends — the total the list can ever show.
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

    /// The name of the newest month in the page starting at `offset` — what §6's
    /// "Đang tải tháng 3, 2026…" names.
    private func monthLabel(offset: Int, today: Date) -> String? {
        guard let currentMonth = calendar.dateInterval(of: .month, for: today)?.start,
            let start = calendar.date(byAdding: .month, value: -offset, to: currentMonth)
        else { return nil }
        let parts = calendar.dateComponents([.year, .month], from: start)
        guard let year = parts.year, let month = parts.month else { return nil }
        return VietnameseDate.monthYearText(year: year, month: month)
    }

    /// Whether a month falls inside the period the user has been logging in.
    private func isWithinRecord(year: Int, month: Int) -> Bool {
        guard let earliestMealDate else { return false }
        let parts = calendar.dateComponents([.year, .month], from: earliestMealDate)
        guard let firstYear = parts.year, let firstMonth = parts.month else { return false }
        return year * 12 + month >= firstYear * 12 + firstMonth
    }
}

extension HistoryDay {
    /// The target this day is drawn against, in one place so the card, the day panel
    /// and the "vượt mục tiêu" filter cannot disagree about it (§8).
    ///
    /// The day's own recorded target where there is one, and the current goal where
    /// there is not — meals logged before `Meal.calorieGoalWhenLogged` existed. The
    /// fallback is the old, wrong-when-the-goal-changed behaviour, kept for old data
    /// only, because a day with no comparison leaves the deviation bar meaningless.
    func goalCalories(fallingBackTo currentGoalCalories: Double) -> Double {
        goalCalories ?? currentGoalCalories
    }
}
