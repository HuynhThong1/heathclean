import Domain
import Testing

@Suite("Calorie goal")
struct CalorieGoalTests {
    let useCase = CalculateCalorieGoalUseCase()

    private func bmr(_ profile: UserProfile) -> Double {
        CalculateCalorieGoalUseCase.basalMetabolicRate(profile: profile)
    }

    // MARK: Basal metabolic rate

    @Test("Mifflin-St Jeor, male")
    func mifflinMale() {
        // 800 + 1125 − 150 + 5
        expectClose(bmr(makeProfile(biologicalSex: .male)), 1780)
    }

    @Test("Mifflin-St Jeor, female")
    func mifflinFemale() {
        // 600 + 1031.25 − 150 − 161
        expectClose(bmr(makeProfile(heightCm: 165, weightKg: 60, biologicalSex: .female)), 1320.25)
    }

    @Test(
        "an unspecified sex uses the midpoint constant",
        arguments: [BiologicalSex?.some(.preferNotToSay), nil]
    )
    func mifflinUnspecified(sex: BiologicalSex?) {
        // 700 + 1062.5 − 150 − 78
        expectClose(bmr(makeProfile(heightCm: 170, weightKg: 70, biologicalSex: sex)), 1534.5)
    }

    // MARK: Calories

    @Test(
        "activity level scales the basal rate",
        arguments: [
            (ActivityLevel.sedentary, 2136.0),
            (.light, 2447.5),
            (.moderate, 2759.0),
            (.active, 3070.5),
            (.veryActive, 3382.0)
        ]
    )
    func activityMultipliers(level: ActivityLevel, expected: Double) {
        // BMR 1780 × multiplier, maintain goal so there is no offset.
        expectClose(useCase.execute(profile: makeProfile(activityLevel: level)).calories, expected)
    }

    @Test(
        "the goal shifts the target",
        arguments: [(WeightGoal.maintain, 2759.0), (.lose, 2259.0), (.gain, 3109.0)]
    )
    func goalDeltas(goal: WeightGoal, expected: Double) {
        // TDEE 2759 at moderate activity.
        expectClose(useCase.execute(profile: makeProfile(goal: goal)).calories, expected)
    }

    @Test("a deficit never drops below the user's own basal rate")
    func deficitClampedToBMR() {
        // Sedentary TDEE 2136 − 500 = 1636, which is below the 1780 BMR.
        let profile = makeProfile(activityLevel: .sedentary, goal: .lose)
        expectClose(useCase.execute(profile: profile).calories, 1780)
    }

    @Test("a deficit never drops below the 1200 kcal floor")
    func deficitClampedToAbsoluteFloor() {
        // Female 45 kg, 150 cm, 60 y: BMR 926.5, sedentary TDEE 1111.8,
        // deficit 611.8 — below both the BMR and the absolute floor.
        let profile = makeProfile(
            age: 60,
            heightCm: 150,
            weightKg: 45,
            biologicalSex: .female,
            activityLevel: .sedentary,
            goal: .lose
        )
        expectClose(bmr(profile), 926.5, "bmr")
        expectClose(useCase.execute(profile: profile).calories, 1200, "calories")
    }

    // MARK: Macros

    @Test(
        "protein rises when losing weight",
        arguments: [(WeightGoal.maintain, 128.0), (.gain, 128.0), (.lose, 144.0)]
    )
    func proteinScalesWithGoal(goal: WeightGoal, expected: Double) {
        expectClose(useCase.execute(profile: makeProfile(goal: goal)).protein, expected)
    }

    @Test("fat is a quarter of energy")
    func fatShare() {
        // 2759 × 0.25 ÷ 9
        expectClose(useCase.execute(profile: makeProfile(goal: .maintain)).fat, 76.639)
    }

    @Test("carbohydrates take the remainder")
    func carbohydrateRemainder() {
        // (2759 − 128·4 − 689.75) ÷ 4
        expectClose(useCase.execute(profile: makeProfile(goal: .maintain)).carbohydrates, 389.3125)
    }

    @Test(
        "macros re-sum to the calorie target",
        arguments: WeightGoal.allCases, ActivityLevel.allCases
    )
    func macrosReSum(weightGoal: WeightGoal, level: ActivityLevel) {
        let goal = useCase.execute(profile: makeProfile(activityLevel: level, goal: weightGoal))
        let energy = goal.protein * 4 + goal.carbohydrates * 4 + goal.fat * 9
        expectClose(energy, goal.calories, tolerance: 1)
    }
}
