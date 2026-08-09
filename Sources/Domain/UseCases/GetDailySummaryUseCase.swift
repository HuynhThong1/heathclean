import Foundation

public struct GetDailySummaryUseCase: Sendable {
    private let mealRepository: any MealRepository

    public init(mealRepository: any MealRepository) {
        self.mealRepository = mealRepository
    }

    public func execute(date: Date, goal: NutritionGoal) async throws -> DailyNutritionSummary {
        let meals = try await mealRepository.meals(on: date)
        return DailyNutritionSummary(date: date, goal: goal, meals: meals)
    }
}
