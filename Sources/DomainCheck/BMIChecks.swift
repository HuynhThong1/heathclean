import Domain

@MainActor
func runBMIChecks(_ runner: CheckRunner) {
    let useCase = CalculateBMIUseCase()

    runner.check("bmi/value") {
        // 70 / 1.75² = 22.857…
        try expectClose(useCase.execute(weightKg: 70, heightCm: 175).value, 22.857)
    }

    runner.check("bmi/value-from-profile") {
        let profile = makeProfile(heightCm: 165, weightKg: 60)
        try expectClose(useCase.execute(profile: profile).value, 22.038)
    }

    runner.check("bmi/category-boundaries") {
        try expect(BMI(value: 18.49).category, .underweight, "just under 18.5")
        try expect(BMI(value: 18.5).category, .normal, "exactly 18.5")
        try expect(BMI(value: 24.99).category, .normal, "just under 25")
        try expect(BMI(value: 25).category, .overweight, "exactly 25")
        try expect(BMI(value: 29.99).category, .overweight, "just under 30")
        try expect(BMI(value: 30).category, .obese, "exactly 30")
    }
}
