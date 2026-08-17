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

    /// Grams of fibre per 1.000 kcal.
    ///
    /// The US Dietary Reference Intake rule (Institute of Medicine, 2005). It is
    /// used rather than a flat 25/38 g because it scales with the target the app
    /// already derived, so a 1.500 kcal goal and a 3.000 kcal goal do not get
    /// the same figure. **This is a reference intake, not a prescription** —
    /// §18 rules out telling the user what to eat, and the UI shows it as a
    /// target beside a figure, never as an instruction.
    static let fiberGramsPerThousandCalories: Double = 14

    /// Millilitres of drinking water per kilogram of body weight.
    ///
    /// **This is a rule of thumb, not a sourced reference value**, and it is
    /// flagged the way the 88-row nutrition table is: widely used clinically at
    /// 30–40 ml/kg, but the actual published references (EFSA, D-A-CH) give flat
    /// *total* water figures that include what comes from food, which is not
    /// what this app can measure. 35 is the midpoint. Replace it if a sourced
    /// value for drinking water alone is adopted.
    static let waterMillilitresPerKilogram: Double = 35

    /// No target below this, whatever the body weight — the same shape as the
    /// calorie floor, and for the same reason: a small person still needs a
    /// sensible amount of water, and a derived figure that trends to nothing is
    /// worse than a floor.
    static let minimumWaterMillilitres: Double = 1500

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

        // Fibre rides on the calorie target, water on body weight. Neither
        // enters the energy arithmetic above: fibre is already inside
        // `carbohydrates`, and water has no energy at all.
        let fiber = calories / 1000 * Self.fiberGramsPerThousandCalories
        let water = max(
            profile.weightKg * Self.waterMillilitresPerKilogram,
            Self.minimumWaterMillilitres
        )

        return NutritionGoal(
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            fiber: fiber,
            waterMillilitres: water
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
