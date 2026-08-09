import Domain
import Foundation
import Testing

@Suite("Meals and daily summary")
struct MealTests {
    let goal = NutritionGoal(calories: 2000, protein: 140, carbohydrates: 220, fat: 65)

    let breakfast = Meal(
        date: referenceDate,
        type: .breakfast,
        items: [
            makeFoodItem(
                name: "White rice",
                calories: 234,
                protein: 4.3,
                carbohydrates: 50,
                fat: 0.4
            ),
            makeFoodItem(
                name: "Fried egg",
                weightGrams: 55,
                calories: 90,
                protein: 6,
                carbohydrates: 0.4,
                fat: 7
            )
        ]
    )

    let lunch = Meal(
        date: referenceDate,
        type: .lunch,
        items: [
            makeFoodItem(
                name: "Grilled chicken",
                weightGrams: 140,
                calories: 231,
                protein: 43,
                carbohydrates: 0,
                fat: 5
            )
        ]
    )

    @Test("a meal totals its items")
    func mealTotals() {
        expectClose(breakfast.calories, 324, "calories")
        expectClose(breakfast.protein, 10.3, "protein")
        expectClose(breakfast.carbohydrates, 50.4, "carbohydrates")
        expectClose(breakfast.fat, 7.4, "fat")
    }

    @Test("a summary aggregates across meals")
    func summaryAggregates() {
        let summary = DailyNutritionSummary(
            date: referenceDate,
            goal: goal,
            meals: [breakfast, lunch]
        )
        expectClose(summary.consumedCalories, 555, "calories")
        expectClose(summary.consumedProtein, 53.3, "protein")
        expectClose(summary.budget.remaining, 1445, "remaining")
        expectClose(summary.remainingProtein, 86.7, "remainingProtein")
        #expect(summary.meals(of: .lunch).count == 1)
        #expect(summary.meals(of: .dinner).isEmpty)
    }

    @Test("the daily summary reads only that day")
    func summaryIsScopedToOneDay() async throws {
        let otherDay = Meal(
            date: referenceDate.addingTimeInterval(60 * 60 * 48),
            type: .dinner,
            items: [makeFoodItem(calories: 999)]
        )
        let repository = InMemoryMealRepository(stored: [breakfast, lunch, otherDay])
        let useCase = GetDailySummaryUseCase(mealRepository: repository)

        let summary = try await useCase.execute(date: referenceDate, goal: goal)
        #expect(summary.meals.count == 2)
        expectClose(summary.consumedCalories, 555)
    }

    @Test("a valid meal is persisted")
    func savesValidMeal() async throws {
        let repository = InMemoryMealRepository()
        try await SaveMealUseCase(mealRepository: repository).execute(breakfast)
        #expect(await repository.count == 1)
    }

    @Test(
        "invalid meals are rejected before they reach storage",
        arguments: [
            (Meal(date: referenceDate, type: .snack, items: []), MealValidationError.noItems),
            (
                Meal(date: referenceDate, type: .snack, items: [makeFoodItem(name: "   ")]),
                .unnamedItem
            ),
            (
                Meal(
                    date: referenceDate,
                    type: .snack,
                    items: [makeFoodItem(name: "Rice", weightGrams: 0)]
                ),
                .nonPositiveWeight(itemName: "Rice")
            ),
            (
                Meal(
                    date: referenceDate,
                    type: .snack,
                    items: [makeFoodItem(name: "Rice", calories: -1)]
                ),
                .negativeNutrient(itemName: "Rice")
            )
        ]
    )
    func rejectsInvalidMeal(meal: Meal, expected: MealValidationError) async throws {
        let repository = InMemoryMealRepository()
        let useCase = SaveMealUseCase(mealRepository: repository)

        await #expect(throws: expected) {
            try await useCase.execute(meal)
        }
        #expect(await repository.count == 0)
    }
}
