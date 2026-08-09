import Domain
import Foundation

@MainActor
func runMealChecks(_ runner: CheckRunner) async {
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

    runner.check("meal/totals-sum-its-items") {
        try expectClose(breakfast.calories, 324, "calories")
        try expectClose(breakfast.protein, 10.3, "protein")
        try expectClose(breakfast.carbohydrates, 50.4, "carbohydrates")
        try expectClose(breakfast.fat, 7.4, "fat")
    }

    runner.check("summary/aggregates-across-meals") {
        let summary = DailyNutritionSummary(
            date: referenceDate,
            goal: goal,
            meals: [breakfast, lunch]
        )
        try expectClose(summary.consumedCalories, 555, "calories")
        try expectClose(summary.consumedProtein, 53.3, "protein")
        try expectClose(summary.budget.remaining, 1445, "remaining")
        try expectClose(summary.remainingProtein, 86.7, "remainingProtein")
        try expect(summary.meals(of: .lunch).count, 1, "lunch count")
        try expect(summary.meals(of: .dinner).count, 0, "dinner count")
    }

    await runner.checkAsync("getDailySummary/reads-only-that-day") {
        let otherDay = Meal(
            date: referenceDate.addingTimeInterval(60 * 60 * 48),
            type: .dinner,
            items: [makeFoodItem(calories: 999)]
        )
        let repository = InMemoryMealRepository(stored: [breakfast, lunch, otherDay])
        let useCase = GetDailySummaryUseCase(mealRepository: repository)

        let summary = try await useCase.execute(date: referenceDate, goal: goal)
        try expect(summary.meals.count, 2, "meal count")
        try expectClose(summary.consumedCalories, 555, "calories")
    }

    await runner.checkAsync("saveMeal/persists-a-valid-meal") {
        let repository = InMemoryMealRepository()
        try await SaveMealUseCase(mealRepository: repository).execute(breakfast)
        let count = await repository.count
        try expect(count, 1, "stored meals")
    }

    await runner.checkAsync("saveMeal/rejects-invalid-meals") {
        let repository = InMemoryMealRepository()
        let useCase = SaveMealUseCase(mealRepository: repository)

        try await expectThrows(MealValidationError.noItems) {
            try await useCase.execute(Meal(date: referenceDate, type: .snack, items: []))
        }
        try await expectThrows(MealValidationError.unnamedItem) {
            let meal = Meal(
                date: referenceDate,
                type: .snack,
                items: [makeFoodItem(name: "   ")]
            )
            try await useCase.execute(meal)
        }
        try await expectThrows(MealValidationError.nonPositiveWeight(itemName: "Rice")) {
            let meal = Meal(
                date: referenceDate,
                type: .snack,
                items: [makeFoodItem(name: "Rice", weightGrams: 0)]
            )
            try await useCase.execute(meal)
        }
        try await expectThrows(MealValidationError.negativeNutrient(itemName: "Rice")) {
            let meal = Meal(
                date: referenceDate,
                type: .snack,
                items: [makeFoodItem(name: "Rice", calories: -1)]
            )
            try await useCase.execute(meal)
        }

        let count = await repository.count
        try expect(count, 0, "nothing was stored")
    }
}
