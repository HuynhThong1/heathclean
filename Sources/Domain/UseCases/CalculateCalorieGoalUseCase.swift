/// Derives the daily calorie and macronutrient targets from the full profile.
///
/// BMI is deliberately not an input: it is health context, not an energy
/// requirement.
public struct CalculateCalorieGoalUseCase: Sendable {
    /// No prescribed target ever falls below this, regardless of deficit.
    static let absoluteMinimumCalories: Double = 1200

    /// Share of energy that comes from fat.
    static let fatEnergyShare: Double = 0.25

    static let caloriesPerGramProtein: Double = 4
    static let caloriesPerGramCarbohydrate: Double = 4
    static let caloriesPerGramFat: Double = 9

    public init() {}

    public func execute(profile: UserProfile) -> NutritionGoal {
        let bmr = Self.basalMetabolicRate(profile: profile)
        let expenditure = bmr * profile.activityLevel.multiplier
        let adjusted = expenditure + profile.goal.dailyCalorieDelta

        // A deficit never takes the user below their own basal rate, and never
        // below the absolute floor.
        let calories = max(adjusted, max(bmr, Self.absoluteMinimumCalories))

        let protein = profile.weightKg * profile.goal.proteinGramsPerKilogram
        let fat = calories * Self.fatEnergyShare / Self.caloriesPerGramFat

        let energyFromProteinAndFat =
            protein * Self.caloriesPerGramProtein + fat * Self.caloriesPerGramFat
        let carbohydrates =
            max(0, calories - energyFromProteinAndFat) / Self.caloriesPerGramCarbohydrate

        return NutritionGoal(
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat
        )
    }

    /// Mifflin-St Jeor.
    ///
    /// An unspecified sex uses the midpoint of the male and female constants.
    public static func basalMetabolicRate(profile: UserProfile) -> Double {
        let constant: Double =
            switch profile.biologicalSex {
            case .male: 5
            case .female: -161
            case .preferNotToSay, nil: -78
            }

        return 10 * profile.weightKg
            + 6.25 * profile.heightCm
            - 5 * Double(profile.age)
            + constant
    }
}
