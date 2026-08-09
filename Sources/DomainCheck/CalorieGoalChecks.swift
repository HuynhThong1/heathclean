import Domain

@MainActor
func runCalorieGoalChecks(_ runner: CheckRunner) {
    let useCase = CalculateCalorieGoalUseCase()
    let bmr = CalculateCalorieGoalUseCase.basalMetabolicRate(profile:)

    runner.check("bmr/mifflin-male") {
        // 800 + 1125 − 150 + 5
        try expectClose(bmr(makeProfile(biologicalSex: .male)), 1780)
    }

    runner.check("bmr/mifflin-female") {
        // 600 + 1031.25 − 150 − 161
        try expectClose(
            bmr(makeProfile(heightCm: 165, weightKg: 60, biologicalSex: .female)),
            1320.25
        )
    }

    runner.check("bmr/mifflin-unspecified-uses-midpoint") {
        // 700 + 1062.5 − 150 − 78
        let stated = makeProfile(heightCm: 170, weightKg: 70, biologicalSex: .preferNotToSay)
        let absent = makeProfile(heightCm: 170, weightKg: 70, biologicalSex: nil)
        try expectClose(bmr(stated), 1534.5, "preferNotToSay")
        try expectClose(bmr(absent), 1534.5, "nil sex")
    }

    runner.check("calorieGoal/activity-multipliers") {
        // BMR 1780 × multiplier, maintain goal so there is no offset.
        let expected: [(ActivityLevel, Double)] = [
            (.sedentary, 2136),
            (.light, 2447.5),
            (.moderate, 2759),
            (.active, 3070.5),
            (.veryActive, 3382)
        ]
        for (level, calories) in expected {
            let goal = useCase.execute(profile: makeProfile(activityLevel: level))
            try expectClose(goal.calories, calories, level.rawValue)
        }
    }

    runner.check("calorieGoal/goal-deltas") {
        // TDEE 2759 at moderate activity.
        try expectClose(useCase.execute(profile: makeProfile(goal: .maintain)).calories, 2759)
        try expectClose(useCase.execute(profile: makeProfile(goal: .lose)).calories, 2259)
        try expectClose(useCase.execute(profile: makeProfile(goal: .gain)).calories, 3109)
    }

    runner.check("calorieGoal/deficit-clamped-to-bmr") {
        // Sedentary TDEE 2136 − 500 = 1636, which is below the 1780 BMR.
        let profile = makeProfile(activityLevel: .sedentary, goal: .lose)
        try expectClose(useCase.execute(profile: profile).calories, 1780)
    }

    runner.check("calorieGoal/deficit-clamped-to-absolute-floor") {
        // Female 45 kg, 150 cm, 60 y: BMR 926.5, sedentary TDEE 1111.8,
        // deficit 611.8 — below both the BMR and the 1200 kcal floor.
        let profile = makeProfile(
            age: 60,
            heightCm: 150,
            weightKg: 45,
            biologicalSex: .female,
            activityLevel: .sedentary,
            goal: .lose
        )
        try expectClose(bmr(profile), 926.5, "bmr")
        try expectClose(useCase.execute(profile: profile).calories, 1200, "calories")
    }

    runner.check("macros/protein-scales-with-goal") {
        try expectClose(useCase.execute(profile: makeProfile(goal: .maintain)).protein, 128)
        try expectClose(useCase.execute(profile: makeProfile(goal: .gain)).protein, 128)
        try expectClose(useCase.execute(profile: makeProfile(goal: .lose)).protein, 144)
    }

    runner.check("macros/fat-is-quarter-of-energy") {
        let goal = useCase.execute(profile: makeProfile(goal: .maintain))
        // 2759 × 0.25 ÷ 9
        try expectClose(goal.fat, 76.639)
    }

    runner.check("macros/carbs-take-the-remainder") {
        let goal = useCase.execute(profile: makeProfile(goal: .maintain))
        // (2759 − 128·4 − 689.75) ÷ 4
        try expectClose(goal.carbohydrates, 389.3125)
    }

    runner.check("macros/re-sum-to-the-calorie-target") {
        for weightGoal in WeightGoal.allCases {
            for level in ActivityLevel.allCases {
                let goal = useCase.execute(
                    profile: makeProfile(activityLevel: level, goal: weightGoal)
                )
                let energy = goal.protein * 4 + goal.carbohydrates * 4 + goal.fat * 9
                try expectClose(
                    energy,
                    goal.calories,
                    "\(weightGoal.rawValue)/\(level.rawValue)",
                    tolerance: 1
                )
            }
        }
    }
}
