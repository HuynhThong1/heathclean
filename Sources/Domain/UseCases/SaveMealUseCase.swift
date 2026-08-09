import Foundation

public enum MealValidationError: Error, Equatable, Sendable {
    case noItems
    case unnamedItem
    case nonPositiveWeight(itemName: String)
    case negativeNutrient(itemName: String)
}

public struct SaveMealUseCase: Sendable {
    private let mealRepository: any MealRepository

    public init(mealRepository: any MealRepository) {
        self.mealRepository = mealRepository
    }

    public func execute(_ meal: Meal) async throws {
        try Self.validate(meal)
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
