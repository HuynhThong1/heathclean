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

    public func meals(of type: MealType) -> [Meal] {
        meals.filter { $0.type == type }
    }
}
