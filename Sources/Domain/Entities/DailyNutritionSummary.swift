import Foundation

public struct DailyNutritionSummary: Sendable, Equatable {
    public let date: Date
    public let goal: NutritionGoal
    public let meals: [Meal]

    public init(date: Date, goal: NutritionGoal, meals: [Meal]) {
        self.date = date
        self.goal = goal
        self.meals = meals
    }

    public var consumedCalories: Double { meals.reduce(0) { $0 + $1.calories } }
    public var consumedProtein: Double { meals.reduce(0) { $0 + $1.protein } }
    public var consumedCarbohydrates: Double { meals.reduce(0) { $0 + $1.carbohydrates } }
    public var consumedFat: Double { meals.reduce(0) { $0 + $1.fat } }

    public var budget: DailyCalorieBudget {
        DailyCalorieBudget(target: goal.calories, consumed: consumedCalories)
    }

    public var remainingProtein: Double { goal.protein - consumedProtein }
    public var remainingCarbohydrates: Double { goal.carbohydrates - consumedCarbohydrates }
    public var remainingFat: Double { goal.fat - consumedFat }

    // MARK: Fibre

    /// The day's fibre, or **`nil` when nothing logged today carries a figure**.
    ///
    /// `nil` is not `0`. A day of scanned meals has no fibre data at all — the
    /// gateway does not return it — and reporting `0 g` there would say the user
    /// ate none. The dashboard draws the bar only when this is non-`nil`.
    public var consumedFiber: Double? {
        guard meals.contains(where: \.hasAnyFiber) else { return nil }
        return meals.reduce(0) { $0 + $1.knownFiber }
    }

    /// Foods logged today with no fibre figure. Non-zero means the total above
    /// is a floor rather than a sum, and the screen has to say so.
    public var itemsMissingFiber: Int {
        meals.reduce(0) { $0 + $1.itemsMissingFiber }
    }

    /// `nil` for the same reason `consumedFiber` is.
    public var remainingFiber: Double? {
        consumedFiber.map { goal.fiber - $0 }
    }

    public func meals(of type: MealType) -> [Meal] {
        meals.filter { $0.type == type }
    }
}
