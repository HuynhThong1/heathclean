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
    /// Portion proposed by the model before the user confirmed or corrected it.
    /// Keeping this beside the final `weightGrams` makes §22's correction rate
    /// measurable after the scan screen has gone away.
    public var aiEstimatedWeightGrams: Double?

    /// Provenance returned by the nutrition resolver. Older/manual rows keep
    /// these nil; `nutritionIsReference` distinguishes the development table
    /// from an external source without guessing from a display name.
    public var nutritionSource: String?
    public var nutritionSourceID: String?
    public var nutritionSourceURL: String?
    public var nutritionIsReference: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        weightGrams: Double,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        aiConfidence: Double? = nil,
        aiEstimatedWeightGrams: Double? = nil,
        nutritionSource: String? = nil,
        nutritionSourceID: String? = nil,
        nutritionSourceURL: String? = nil,
        nutritionIsReference: Bool = false
    ) {
        self.id = id
        self.name = name
        self.weightGrams = weightGrams
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.aiConfidence = aiConfidence
        self.aiEstimatedWeightGrams = aiEstimatedWeightGrams
        self.nutritionSource = nutritionSource
        self.nutritionSourceID = nutritionSourceID
        self.nutritionSourceURL = nutritionSourceURL
        self.nutritionIsReference = nutritionIsReference
    }

    public var wasPortionCorrected: Bool {
        guard let aiEstimatedWeightGrams else { return false }
        return abs(weightGrams - aiEstimatedWeightGrams) > 0.5
    }
}
