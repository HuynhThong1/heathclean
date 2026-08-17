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

    /// Dietary fibre in grams, **or `nil` when nobody measured it**.
    ///
    /// Optional rather than defaulting to zero, and this is the whole of the
    /// design: the gateway contract (`plan.md` §25) has no fibre field, so every
    /// scanned food arrives without one. A `0` there would tell a user who logs
    /// by scanning that they ate no fibre today, when what happened is that
    /// nothing measured it — the same mistake as a switch that schedules
    /// nothing, with a number attached.
    ///
    /// So `nil` and `0` mean different things here and every reader keeps them
    /// apart: `Meal.knownFiber` sums only what is known, and
    /// `DailyNutritionSummary.consumedFiber` is `nil` for a day where nothing
    /// is. Manual entry is currently the only way a value gets in.
    public var fiber: Double?

    /// Populated only when the item came from image recognition. Always `nil`
    /// for manual entry.
    public var aiConfidence: Double?
    /// Portion proposed by the model before the user confirmed or corrected it.
    /// Keeping this beside the final `weightGrams` makes §22's correction rate
    /// measurable after the scan screen has gone away.
    public var aiEstimatedWeightGrams: Double?
    /// Dish name proposed by the model, likewise. §22 stores the predicted food
    /// *and* the predicted weight against what was confirmed; without this half
    /// a misidentification leaves no trace at all, because renaming overwrites
    /// the only copy.
    public var aiEstimatedName: String?

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
        fiber: Double? = nil,
        aiConfidence: Double? = nil,
        aiEstimatedWeightGrams: Double? = nil,
        aiEstimatedName: String? = nil,
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
        self.fiber = fiber
        self.aiConfidence = aiConfidence
        self.aiEstimatedWeightGrams = aiEstimatedWeightGrams
        self.aiEstimatedName = aiEstimatedName
        self.nutritionSource = nutritionSource
        self.nutritionSourceID = nutritionSourceID
        self.nutritionSourceURL = nutritionSourceURL
        self.nutritionIsReference = nutritionIsReference
    }

    /// This item came from a scan rather than being typed in — the denominator
    /// for every §22 rate. `aiConfidence` is the marker because it is the one
    /// field only the recognition path can supply.
    public var cameFromScan: Bool { aiConfidence != nil }

    public var wasPortionCorrected: Bool {
        guard let aiEstimatedWeightGrams else { return false }
        return abs(weightGrams - aiEstimatedWeightGrams) > 0.5
    }

    /// The user gave the dish a different name than the model did.
    public var wasRenamed: Bool {
        guard let aiEstimatedName else { return false }
        return !VietnameseTextComparison.areSameName(name, aiEstimatedName)
    }

    /// Either half of §22's correction, which is what "% AI cần sửa" counts.
    public var wasCorrected: Bool { wasPortionCorrected || wasRenamed }
}
