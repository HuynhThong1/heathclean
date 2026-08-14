import Foundation

/// One day of a `HistoryMonth`, and always a day something was logged on —
/// HISTORY_SPEC §0.1: "ngày trống không tồn tại trong UI".
///
/// It exists rather than a `[Date: [Meal]]` because a day is a unit with figures
/// of its own: the totals below are what the card's deviation bar and the day
/// panel read, and they have to be the same numbers in both places.
public struct HistoryDay: Sendable, Equatable, Identifiable {
    /// Start of day, in the calendar the use case was built with.
    public let date: Date

    /// Oldest first, so a day reads as a timeline.
    public let meals: [Meal]

    public init(date: Date, meals: [Meal]) {
        self.date = date
        self.meals = meals
    }

    public var id: Date { date }

    public var hasMeals: Bool { !meals.isEmpty }

    public var calories: Double { meals.reduce(0) { $0 + $1.calories } }
    public var protein: Double { meals.reduce(0) { $0 + $1.protein } }
    public var carbohydrates: Double { meals.reduce(0) { $0 + $1.carbohydrates } }
    public var fat: Double { meals.reduce(0) { $0 + $1.fat } }

    public func meals(of type: MealType) -> [Meal] {
        meals.filter { $0.type == type }
    }

    /// The calorie target this day is measured against — HISTORY_SPEC §8.
    ///
    /// The stamp on the **last meal that carries one**, which is the target in force
    /// at the end of the day. A goal changed at lunchtime leaves two figures on one
    /// day and the day has to pick one; the later is the one the user was aiming at
    /// when they stopped eating, and it is also the one that agrees with the
    /// dashboard on the day itself.
    ///
    /// `nil` when nothing on the day recorded a target: every meal predates the
    /// field, or each was saved while the profile could not be read. That is the
    /// caller's cue to fall back to the current goal — the figure is then wrong in
    /// the old way, for old data only, and a day with no comparison at all would
    /// leave the bar with nothing to mean.
    public var goalCalories: Double? {
        meals.last(where: { $0.calorieGoalWhenLogged != nil })?.calorieGoalWhenLogged
    }

    /// Every photo on the day, in the order the meals were eaten — the count
    /// behind the card's "Có N ảnh" (§7).
    ///
    /// There is deliberately no "the day's photo" beside this. There was one:
    /// `representativePhotoID`, the newest meal that had a picture, for a day cell
    /// that drew a single thumbnail. HISTORY_SPEC's card draws a chip per meal,
    /// each with its own, so a day no longer has one representative picture — and a
    /// second rule for which photo stands for a day is exactly the kind of thing
    /// that starts disagreeing with the first.
    public var photos: [MealPhoto] { meals.flatMap(\.photos) }

    public var photoCount: Int { meals.reduce(0) { $0 + $1.photos.count } }
}

/// One calendar month of logged meals — the unit history pages in (§32.5).
public struct HistoryMonth: Sendable, Equatable, Identifiable {
    public let year: Int
    public let month: Int

    /// **Only days something was logged on**, newest first — the same direction
    /// as the months themselves.
    ///
    /// This used to be every day of the month, empty ones included, because a
    /// calendar grid has to draw a cell for each. On device that layout spent
    /// almost all of its pixels on days with nothing on them, and MVP does not
    /// allow back-dating, so tapping an empty cell opened a sheet that could only
    /// say "nothing here" — 90% of the grid had no action behind it. History is a
    /// list of days that happened again, which is also how §6.11 draws it.
    public let days: [HistoryDay]

    public init(year: Int, month: Int, days: [HistoryDay]) {
        self.year = year
        self.month = month
        self.days = days
    }

    /// `yyyy-MM`, which is also the accessibility identifier the section uses.
    public var id: String { String(format: "%04d-%02d", year, month) }

    public var calories: Double { days.reduce(0) { $0 + $1.calories } }

    /// Whether the month is worth drawing at all. A month with nothing logged is
    /// still *returned* — paging counts months, not days — but nothing renders it.
    public var hasMeals: Bool { !days.isEmpty }
}
