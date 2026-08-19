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

    /// 0…1 as reported by the model, or **`nil` for a food the user typed in
    /// themselves**.
    ///
    /// The scan flow lets them add one when the analysis fails or comes back
    /// with nothing, so the photo they just took is still a meal they can log —
    /// and a number here would be the model's opinion about a dish it never
    /// reported. `nil` is what keeps the two apart everywhere it matters:
    /// `foodItem` leaves `aiConfidence` and both `aiEstimated…` fields `nil`, so
    /// a hand-typed food stays out of every §22 denominator
    /// (`FoodItem.cameFromScan`), and being `Optional` means no screen can draw
    /// a confidence badge for a figure nobody predicted without saying what to
    /// do when there is none.
    public var confidence: Double?

    /// `false` when the food was not found in the nutrition database. Its
    /// nutrition is zero and the user has to supply it — showing zeros as fact
    /// would be worse than admitting the gap.
    public var isResolved: Bool

    public var nutritionSource: String?
    public var nutritionSourceID: String?
    public var nutritionSourceURL: String?
    public var nutritionIsReference: Bool

    /// Dietary fibre in grams, or `nil` when the resolver had none.
    ///
    /// Optional all the way through for the reason `FoodItem.fiber` gives: a
    /// nutrition row without a fibre figure is not a food with no fibre. The
    /// gateway's `/v1/meals/analyze` does not send this field yet, so today it
    /// is always `nil` on a real scan — and being `Optional` is what lets the
    /// gateway start sending it without a client release becoming a
    /// prerequisite.
    public var fiber: Double?

    /// What the model first estimated, kept so a correction can be measured
    /// against it (`plan.md` §22).
    public let originalWeightGrams: Double

    /// What the model first called it, for the same reason and with the same
    /// rule: **nothing may write to it after init.**
    ///
    /// §22 stores the predicted food *and* the predicted weight against what the
    /// user confirmed, and this is the food half. It matters more than the weight
    /// half does: three photos through `gemini-3.1-flash-lite` returned bún bò
    /// Huế as "Phở bò" at 0.98, which no confidence threshold will ever catch —
    /// the only record that it happened is the user changing the name, and that
    /// record does not exist unless the original is kept.
    public let originalName: String

    public init(
        id: UUID = UUID(),
        name: String,
        nameEn: String? = nil,
        weightGrams: Double,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        confidence: Double?,
        isResolved: Bool,
        fiber: Double? = nil,
        originalWeightGrams: Double? = nil,
        originalName: String? = nil,
        nutritionSource: String? = nil,
        nutritionSourceID: String? = nil,
        nutritionSourceURL: String? = nil,
        nutritionIsReference: Bool = false
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
        self.fiber = fiber
        self.originalWeightGrams = originalWeightGrams ?? weightGrams
        self.originalName = originalName ?? name
        self.nutritionSource = nutritionSource
        self.nutritionSourceID = nutritionSourceID
        self.nutritionSourceURL = nutritionSourceURL
        self.nutritionIsReference = nutritionIsReference
    }

    /// Below this the UI flags the item for checking (§4).
    public static let lowConfidenceThreshold: Double = 0.75

    /// A hand-typed food is never flagged: there is no estimate to doubt.
    public var isLowConfidence: Bool {
        guard let confidence else { return false }
        return confidence < Self.lowConfidenceThreshold
    }

    /// This food is the model's proposal, rather than one the user typed into
    /// the scan flow themselves. `confidence` is the marker because it is the
    /// one field only the recognition path can supply — the same rule
    /// `FoodItem.cameFromScan` uses on the other side of the boundary.
    public var isFromModel: Bool { confidence != nil }

    /// A food typed in by hand starts nameless, and a nameless food must not be
    /// saved. The check lives here rather than in the view because
    /// `ScanModel.canConfirm` is what reads it.
    public var hasName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A food the user adds themselves on the review screen — the way out when
    /// the analysis fails or reports nothing, so the photo they just took is
    /// still the meal they log rather than something to throw away.
    ///
    /// Unresolved on purpose: its nutrition arrives through `resolved(…)`, the
    /// same path a dish outside the nutrition table takes, so figures are typed
    /// in one place rather than two.
    public static func typedByHand(weightGrams: Double = 100) -> RecognizedFood {
        RecognizedFood(
            name: "",
            weightGrams: weightGrams,
            calories: 0,
            protein: 0,
            carbohydrates: 0,
            fat: 0,
            confidence: nil,
            isResolved: false
        )
    }

    /// **Named to match `FoodItem`'s**, and it was not: this used to be
    /// `wasCorrected`, which on `FoodItem` means *either* correction. Two
    /// closely related types answering the same question differently under the
    /// same name is how a §22 rate quietly starts counting the wrong thing.
    ///
    /// A hand-typed food answers `false` to both halves, because there was no
    /// prediction to correct — the same answer `FoodItem` gives once it is
    /// saved, where the `aiEstimated…` fields are `nil`. The two types have to
    /// agree here; `AICorrectionTests` pins that they do.
    public var wasPortionCorrected: Bool {
        guard isFromModel else { return false }
        return abs(weightGrams - originalWeightGrams) > 0.5
    }

    /// The user gave the dish a different name than the model did.
    public var wasRenamed: Bool {
        guard isFromModel else { return false }
        return !VietnameseTextComparison.areSameName(name, originalName)
    }

    /// Either half, the same as `FoodItem.wasCorrected`.
    public var wasCorrected: Bool { wasPortionCorrected || wasRenamed }

    /// Nutrition the database did not have, supplied by the user for the weight
    /// currently shown.
    ///
    /// Without this an unresolved food is a dead end: the gateway sets
    /// `isResolved`, renaming in the client cannot flip it, and confirming is
    /// blocked while anything is unresolved — so a dish outside the nutrition
    /// table could never be saved at all. `plan.md` §2 gives nutrition to the
    /// database, but says nothing about a dish the database does not know; this
    /// is that branch, and §4's "always correctable" is the reason it belongs to
    /// the user rather than to a guess.
    ///
    /// `originalWeightGrams` is deliberately left alone. It is what §22 measures
    /// a portion correction against, and `scaled(toWeightGrams:)` already
    /// derives its baseline from the current values — so figures entered here
    /// rescale correctly without pretending the model estimated this weight.
    ///
    /// `fiber` stays optional here too, and blank stays `nil`: someone typing a
    /// dish the database never heard of is the least likely person to know its
    /// fibre, and a required zero would be a figure they did not mean.
    public func resolved(
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        fiber: Double? = nil
    ) -> RecognizedFood {
        var copy = self
        copy.calories = max(0, calories)
        copy.protein = max(0, protein)
        copy.carbohydrates = max(0, carbohydrates)
        copy.fat = max(0, fat)
        copy.fiber = fiber.map { max(0, $0) }
        copy.isResolved = true
        copy.nutritionSource = "user_entered"
        copy.nutritionSourceID = nil
        copy.nutritionSourceURL = nil
        copy.nutritionIsReference = false
        return copy
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
        // Scales with the portion like every other figure — and stays `nil` if
        // it was `nil`. Half of an unknown is still unknown; `map` is what keeps
        // a missing figure from becoming a zero the moment a portion is edited.
        copy.fiber = fiber.map { $0 / max(weightGrams, .leastNonzeroMagnitude) * newWeight }
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
            fiber: fiber,
            aiConfidence: confidence,
            // Only when a model actually proposed something. A hand-typed food
            // carries an `originalName` and an `originalWeightGrams` because
            // they are `let` and always set, and writing them here would report
            // the user's own first guess as the model's prediction — inflating
            // every §29 accuracy figure with rows the model never saw.
            aiEstimatedWeightGrams: isFromModel ? originalWeightGrams : nil,
            aiEstimatedName: isFromModel ? originalName : nil,
            nutritionSource: nutritionSource,
            nutritionSourceID: nutritionSourceID,
            nutritionSourceURL: nutritionSourceURL,
            nutritionIsReference: nutritionIsReference
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
