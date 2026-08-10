import Foundation

/// One food the recognition pipeline believes it saw, with its nutrition
/// already resolved.
///
/// Separate from `FoodItem` on purpose: this is a *proposal*, not something the
/// user has accepted. It carries confidence and an editable weight, and becomes
/// a `FoodItem` only when confirmed — `plan.md` §2 and §22.
public struct RecognizedFood: Sendable, Equatable, Identifiable {
    public let id: UUID

    public var name: String
    public var nameEn: String?
    public var weightGrams: Double

    public var calories: Double
    public var protein: Double
    public var carbohydrates: Double
    public var fat: Double

    /// 0…1 as reported by the model.
    public var confidence: Double

    /// `false` when the food was not found in the nutrition database. Its
    /// nutrition is zero and the user has to supply it — showing zeros as fact
    /// would be worse than admitting the gap.
    public var isResolved: Bool

    /// What the model first estimated, kept so a correction can be measured
    /// against it (`plan.md` §22).
    public let originalWeightGrams: Double

    public init(
        id: UUID = UUID(),
        name: String,
        nameEn: String? = nil,
        weightGrams: Double,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        confidence: Double,
        isResolved: Bool,
        originalWeightGrams: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.nameEn = nameEn
        self.weightGrams = weightGrams
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.confidence = confidence
        self.isResolved = isResolved
        self.originalWeightGrams = originalWeightGrams ?? weightGrams
    }

    /// Below this the UI flags the item for checking (§4).
    public static let lowConfidenceThreshold: Double = 0.75

    public var isLowConfidence: Bool { confidence < Self.lowConfidenceThreshold }

    public var wasCorrected: Bool {
        abs(weightGrams - originalWeightGrams) > 0.5
    }

    /// Nutrition scales linearly with weight, so a correction rescales it from
    /// the original estimate rather than compounding earlier edits.
    public func scaled(toWeightGrams newWeight: Double) -> RecognizedFood {
        guard originalWeightGrams > 0 else { return self }
        let ratio = newWeight / originalWeightGrams
        let base = calories / max(weightGrams / originalWeightGrams, .leastNonzeroMagnitude)

        var copy = self
        copy.weightGrams = max(0, newWeight)
        copy.calories = base * ratio
        copy.protein = protein / max(weightGrams, .leastNonzeroMagnitude) * newWeight
        copy.carbohydrates = carbohydrates / max(weightGrams, .leastNonzeroMagnitude) * newWeight
        copy.fat = fat / max(weightGrams, .leastNonzeroMagnitude) * newWeight
        return copy
    }

    public var foodItem: FoodItem {
        FoodItem(
            id: id,
            name: name,
            weightGrams: weightGrams,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            aiConfidence: confidence
        )
    }
}

/// What the gateway returns for one photo.
public struct FoodAnalysisResult: Sendable, Equatable {
    public var foods: [RecognizedFood]
    /// Which model produced this, so a result can always be attributed.
    public let provider: String

    public init(foods: [RecognizedFood], provider: String) {
        self.foods = foods
        self.provider = provider
    }

    public var totalCalories: Double { foods.reduce(0) { $0 + $1.calories } }
    public var totalProtein: Double { foods.reduce(0) { $0 + $1.protein } }
    public var totalCarbohydrates: Double { foods.reduce(0) { $0 + $1.carbohydrates } }
    public var totalFat: Double { foods.reduce(0) { $0 + $1.fat } }

    public var needsAttention: Bool {
        foods.contains { $0.isLowConfidence || !$0.isResolved }
    }
}
