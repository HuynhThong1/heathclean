/// Daily targets. Calories are kcal; macros are grams.
public struct NutritionGoal: Sendable, Equatable {
    public var calories: Double
    public var protein: Double
    public var carbohydrates: Double
    public var fat: Double

    public init(calories: Double, protein: Double, carbohydrates: Double, fat: Double) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
    }
}
