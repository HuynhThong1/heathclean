import Foundation

/// One day of a `HistoryMonth`.
///
/// A day with nothing logged is present with an empty `meals`, not absent: the
/// day happened and nothing was eaten on the record, which the month grid draws
/// as a neutral dot. Absent means *not part of the month* — a leading blank or a
/// day that has not arrived yet (§32.3). Keeping those two apart is the whole
/// reason this type exists rather than a `[Date: [Meal]]`.
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

    /// The photo the month grid draws for this day.
    ///
    /// The most recent meal that *has* one, and that meal's first photo. §32.3
    /// says the newest meal's photo; taking the newest meal outright would leave
    /// a day blank whenever the last thing logged was typed in by hand, and
    /// "ảnh gần nhất trong ngày" (§32.2) is the photo, not the meal.
    ///
    /// The rule has to be deterministic or the picture moves between renders,
    /// which is why it reads an ordered array rather than picking from a set.
    public var representativePhotoID: UUID? {
        meals.last(where: { !$0.photos.isEmpty })?.photos.first?.id
    }

    /// Every photo on the day, in the order the meals were eaten — what the day
    /// sheet shows, and the count behind §32.2's badge.
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
