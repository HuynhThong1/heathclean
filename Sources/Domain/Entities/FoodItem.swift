import Foundation

/// A single food as logged in a meal. Calories and macros are the resolved
/// values for `weightGrams`, not per-100g figures.
public struct FoodItem: Sendable, Equatable, Identifiable {
    public let id: UUID

    public var name: String
    public var weightGrams: Double

    public var calories: Double
    public var protein: Double
    public var carbohydrates: Double
    public var fat: Double

    /// Populated only when the item came from image recognition. Always `nil`
    /// for manual entry.
    public var aiConfidence: Double?

    public init(
        id: UUID = UUID(),
        name: String,
        weightGrams: Double,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        aiConfidence: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.weightGrams = weightGrams
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.aiConfidence = aiConfidence
    }
}
