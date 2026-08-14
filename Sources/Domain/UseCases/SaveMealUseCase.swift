import Foundation

public enum MealValidationError: Error, Equatable, Sendable {
    case noItems
    case unnamedItem
    case nonPositiveWeight(itemName: String)
    case negativeNutrient(itemName: String)
}

public struct SaveMealUseCase: Sendable {
    private let mealRepository: any MealRepository
    private let userRepository: any UserRepository

    public init(mealRepository: any MealRepository, userRepository: any UserRepository) {
        self.mealRepository = mealRepository
        self.userRepository = userRepository
    }

    /// Validates the meal, stamps it with the day's calorie target, and stores it.
    ///
    /// **The stamp happens here rather than at the call sites** — manual entry and
    /// the scan today, whatever logs a meal tomorrow — because a meal saved without
    /// it silently loses the only record of what that day was aiming for, and there
    /// is no repair: `UserProfile` keeps one current goal. One writer is the way to
    /// be sure a new flow cannot forget.
    ///
    /// A profile that cannot be read **does not fail the meal**. The same rule as a
    /// failed photo write or a failed weight write: the meal is what the user asked
    /// to save, and `Meal.calorieGoalWhenLogged` is documented as optional for
    /// exactly this. A caller that already knows the goal may pass it in, and then
    /// this reads nothing.
    public func execute(_ meal: Meal) async throws {
        try Self.validate(meal)
        var meal = meal
        if meal.calorieGoalWhenLogged == nil {
            meal.calorieGoalWhenLogged = try? await userRepository.load()?.goal.calories
        }
        try await mealRepository.save(meal)
    }

    static func validate(_ meal: Meal) throws {
        guard !meal.items.isEmpty else { throw MealValidationError.noItems }

        for item in meal.items {
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MealValidationError.unnamedItem
            }
            guard item.weightGrams > 0 else {
                throw MealValidationError.nonPositiveWeight(itemName: item.name)
            }
            guard item.calories >= 0, item.protein >= 0, item.carbohydrates >= 0, item.fat >= 0
            else {
                throw MealValidationError.negativeNutrient(itemName: item.name)
            }
        }
    }
}
