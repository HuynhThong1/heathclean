import Domain
import Testing

@Suite("BMI")
struct BMITests {
    let useCase = CalculateBMIUseCase()

    @Test("is weight over height squared")
    func value() {
        // 70 / 1.75² = 22.857…
        expectClose(useCase.execute(weightKg: 70, heightCm: 175).value, 22.857)
    }

    @Test("can be taken straight from a profile")
    func valueFromProfile() {
        let profile = makeProfile(heightCm: 165, weightKg: 60)
        expectClose(useCase.execute(profile: profile).value, 22.038)
    }

    @Test(
        "categories use the WHO cutoffs",
        arguments: [
            (18.49, BMICategory.underweight),
            (18.5, .normal),
            (24.99, .normal),
            (25.0, .overweight),
            (29.99, .overweight),
            (30.0, .obese)
        ]
    )
    func categoryBoundaries(value: Double, expected: BMICategory) {
        #expect(BMI(value: value).category == expected)
    }
}
