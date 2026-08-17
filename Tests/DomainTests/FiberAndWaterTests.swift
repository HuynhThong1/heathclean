import Domain
import Foundation
import Testing

/// `plan.md` Phase 5's fibre and water.
///
/// Most of these pin one rule: **an unmeasured figure is not a zero.** The
/// gateway returns no fibre at all, so a scanned day has none — and every way
/// of reporting that as `0 g` tells the user something false about what they
/// ate.
@Suite("Fibre and water")
struct FiberAndWaterTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func item(_ name: String, fiber: Double?) -> FoodItem {
        FoodItem(
            name: name,
            weightGrams: 100,
            calories: 100,
            protein: 5,
            carbohydrates: 20,
            fat: 1,
            fiber: fiber
        )
    }

    private func summary(_ items: [FoodItem], goal: NutritionGoal) -> DailyNutritionSummary {
        DailyNutritionSummary(
            date: referenceDate,
            goal: goal,
            meals: [Meal(date: referenceDate, type: .lunch, items: items)]
        )
    }

    private var goal: NutritionGoal {
        CalculateCalorieGoalUseCase().execute(profile: makeProfile())
    }

    // MARK: Fibre — nil is not zero

    @Test("a day with nothing measured reports no fibre at all, not zero")
    func unmeasuredDayHasNoFibre() {
        // Exactly what a day of scanned meals looks like: the gateway contract
        // has no fibre field, so every item arrives without one.
        let day = summary([item("Cơm trắng", fiber: nil), item("Sườn nướng", fiber: nil)], goal: goal)

        #expect(day.consumedFiber == nil)
        #expect(day.remainingFiber == nil)
        #expect(day.itemsMissingFiber == 2)
    }

    @Test("a food measured at zero fibre is not the same as one never measured")
    func measuredZeroIsAFigure() {
        let day = summary([item("Dầu ăn", fiber: 0)], goal: goal)

        #expect(day.consumedFiber != nil, "0 g was measured, so there is a figure to show")
        expectClose(day.consumedFiber ?? -1, 0)
        #expect(day.itemsMissingFiber == 0)
    }

    @Test("a partly measured day totals what it knows and says what it does not")
    func partlyMeasuredDay() {
        let day = summary(
            [item("Rau muống", fiber: 2.5), item("Cơm trắng", fiber: nil), item("Đậu", fiber: 4)],
            goal: goal
        )

        expectClose(day.consumedFiber ?? -1, 6.5)
        #expect(day.itemsMissingFiber == 1, "so the 6,5 g reads as a floor, not a total")
    }

    @Test("an empty day has no fibre figure either")
    func emptyDay() {
        let day = DailyNutritionSummary(date: referenceDate, goal: goal, meals: [])

        #expect(day.consumedFiber == nil)
        #expect(day.itemsMissingFiber == 0)
    }

    // MARK: Fibre — the target

    @Test("the fibre target follows the calorie target at 14 g per 1.000 kcal")
    func fibreTargetScalesWithCalories() {
        // Reference profile: BMR 1780, moderate ×1.55, maintain → 2759 kcal.
        let goal = CalculateCalorieGoalUseCase().execute(profile: makeProfile())
        expectClose(goal.calories, 2759, "calories")
        expectClose(goal.fiber, 38.626, "fibre")
    }

    @Test("a smaller calorie target gets a smaller fibre target")
    func fibreTargetIsNotFlat() {
        let large = CalculateCalorieGoalUseCase()
            .execute(profile: makeProfile(activityLevel: .veryActive))
        let small = CalculateCalorieGoalUseCase()
            .execute(profile: makeProfile(activityLevel: .sedentary, goal: .lose))

        #expect(large.fiber > small.fiber)
    }

    @Test("fibre stays out of the energy sum")
    func fibreDoesNotDoubleCount() {
        // The rule `macrosReSum` pins, restated where fibre could break it:
        // fibre is a component of carbohydrates and is already counted there.
        let goal = CalculateCalorieGoalUseCase().execute(profile: makeProfile())
        let energy = goal.protein * 4 + goal.carbohydrates * 4 + goal.fat * 9

        expectClose(energy, goal.calories, tolerance: 1)
        #expect(goal.fiber > 0, "and it is still a real target")
    }

    // MARK: Fibre through the scan path

    private func recognized(fiber: Double?) -> RecognizedFood {
        RecognizedFood(
            name: "Cơm trắng",
            weightGrams: 180,
            calories: 234,
            protein: 4.9,
            carbohydrates: 50.4,
            fat: 0.5,
            confidence: 0.92,
            isResolved: true,
            fiber: fiber
        )
    }

    @Test("fibre scales with the portion like every other figure")
    func fibreScalesWithPortion() {
        let doubled = recognized(fiber: 0.9).scaled(toWeightGrams: 360)

        expectClose(doubled.fiber ?? -1, 1.8)
        expectClose(doubled.calories, 468, "and the calories still do too")
    }

    @Test("half of an unknown is still unknown")
    func scalingKeepsAMissingFigureMissing() {
        // The one that would go wrong quietly: a `0` default here would turn
        // every scanned food into "measured at zero" the moment someone edited
        // its portion, and the day would start reporting a fibre total it has
        // no basis for.
        #expect(recognized(fiber: nil).scaled(toWeightGrams: 90).fiber == nil)
    }

    @Test("nutrition typed for an unresolved food may leave fibre out")
    func suppliedNutritionKeepsFibreOptional() {
        let unknown = RecognizedFood(
            name: "Món chưa rõ",
            weightGrams: 80,
            calories: 0,
            protein: 0,
            carbohydrates: 0,
            fat: 0,
            confidence: 0.41,
            isResolved: false
        )

        let withoutFibre = unknown.resolved(calories: 150, protein: 3, carbohydrates: 20, fat: 5)
        #expect(withoutFibre.isResolved, "the food resolves on calories alone")
        #expect(withoutFibre.fiber == nil, "and claims nothing about fibre")

        let withFibre = unknown.resolved(
            calories: 150, protein: 3, carbohydrates: 20, fat: 5, fiber: 2.5
        )
        expectClose(withFibre.fiber ?? -1, 2.5)
    }

    @Test("a confirmed scan carries its fibre into the saved food")
    func fibreSurvivesConfirmation() {
        #expect(recognized(fiber: 0.7).foodItem.fiber == 0.7)
        #expect(recognized(fiber: nil).foodItem.fiber == nil)
    }

    // MARK: Water — the target

    @Test("the water target is 35 ml per kilogram")
    func waterTargetFollowsWeight() {
        // 80 kg × 35
        expectClose(goal.waterMillilitres, 2800)
    }

    @Test("the water target never falls below the floor")
    func waterTargetHasAFloor() {
        // 40 kg × 35 = 1400, below the 1500 floor.
        let light = CalculateCalorieGoalUseCase()
            .execute(profile: makeProfile(heightCm: 150, weightKg: 40, biologicalSex: .female))
        expectClose(light.waterMillilitres, 1500)
    }

    // MARK: Water — the day

    @Test("the day totals its drinks")
    func waterTotals() {
        let day = DailyWater(
            target: 2800,
            entries: [
                WaterEntry(date: referenceDate, millilitres: 250),
                WaterEntry(date: referenceDate.addingTimeInterval(60), millilitres: 500)
            ]
        )

        expectClose(day.consumed, 750)
        expectClose(day.remaining, 2050)
        expectClose(day.fraction, 750 / 2800)
    }

    @Test("drinking past the target leaves nothing remaining, never a debt")
    func waterNeverGoesNegative() {
        let day = DailyWater(
            target: 2000,
            entries: [WaterEntry(date: referenceDate, millilitres: 2500)]
        )

        expectClose(day.remaining, 0)
        expectClose(day.fraction, 1, "and the bar stops at full")
    }

    @Test("undo takes back the drink that was logged last, not the smallest")
    func undoTakesTheLatest() {
        let first = WaterEntry(date: referenceDate, millilitres: 500)
        let second = WaterEntry(date: referenceDate.addingTimeInterval(120), millilitres: 250)
        // Deliberately out of order: a repository returns what it returns, and
        // "most recent" is a fact about the dates rather than about the array.
        let day = DailyWater(target: 2000, entries: [second, first])

        #expect(day.mostRecent == second)
    }

    @Test("a day with no drinks has nothing to undo")
    func nothingToUndo() {
        let day = DailyWater(target: 2000, entries: [])

        #expect(day.mostRecent == nil)
        expectClose(day.fraction, 0)
        expectClose(day.remaining, 2000)
    }
}
