/// Daily targets. Calories are kcal; macros are grams; water is millilitres.
public struct NutritionGoal: Sendable, Equatable {
    public var calories: Double
    public var protein: Double
    public var carbohydrates: Double
    public var fat: Double

    /// Dietary fibre, in grams.
    ///
    /// **Not a fourth macronutrient, and it must never join the energy sum.**
    /// Fibre is a *component* of `carbohydrates`, already counted there; adding
    /// it to `protein × 4 + carbohydrates × 4 + fat × 9` would double count it
    /// and the macros would stop re-summing to `calories`.
    public var fiber: Double

    /// Drinking water, in millilitres.
    ///
    /// Not nutrition in the macro sense — it contributes no energy and is
    /// logged on its own rather than through a meal. It lives here because it
    /// is a **daily target derived from the profile**, which is what this type
    /// is, and a second goal type holding one number would be worse.
    public var waterMillilitres: Double

    /// `fiber` and `waterMillilitres` default to zero **for fixtures only**.
    /// Every goal the app actually uses comes from
    /// `CalculateCalorieGoalUseCase`, which always supplies both; a zero target
    /// means "no target", and the views draw nothing rather than a full bar.
    public init(
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        fiber: Double = 0,
        waterMillilitres: Double = 0
    ) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.waterMillilitres = waterMillilitres
    }
}
