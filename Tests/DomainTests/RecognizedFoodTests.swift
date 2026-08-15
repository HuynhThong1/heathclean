import Domain
import Foundation
import Testing

@Suite("Recognized food")
struct RecognizedFoodTests {
    private func makeFood(
        weight: Double = 180,
        calories: Double = 234,
        confidence: Double = 0.9,
        resolved: Bool = true
    ) -> RecognizedFood {
        RecognizedFood(
            name: "Cơm trắng",
            weightGrams: weight,
            calories: calories,
            protein: 4.3,
            carbohydrates: 50,
            fat: 0.4,
            confidence: confidence,
            isResolved: resolved
        )
    }

    @Test("supplying nutrition resolves a food the database did not have")
    func manualResolution() {
        let unknown = makeFood(weight: 200, calories: 0, resolved: false)
        #expect(!unknown.isResolved)

        let fixed = unknown.resolved(calories: 300, protein: 12, carbohydrates: 40, fat: 8)
        #expect(fixed.isResolved)
        #expect(fixed.nutritionSource == "user_entered")
        expectClose(fixed.calories, 300)
        expectClose(fixed.protein, 12)
        expectClose(fixed.weightGrams, 200, "weight is untouched")
    }

    @Test("negative figures are floored rather than trusted")
    func manualResolutionRejectsNegatives() {
        let fixed = makeFood(resolved: false)
            .resolved(calories: -50, protein: -1, carbohydrates: 0, fat: 0)
        expectClose(fixed.calories, 0)
        expectClose(fixed.protein, 0)
    }

    @Test("nutrition entered by hand still rescales with the portion")
    func manualResolutionThenRescale() {
        // 200 g estimated, user cut it to 150 g, then supplied 300 kcal for what
        // is on screen. Changing the portion again has to work from those 300,
        // not from the zero the database returned.
        let corrected = makeFood(weight: 200, calories: 0, resolved: false)
            .scaled(toWeightGrams: 150)
            .resolved(calories: 300, protein: 12, carbohydrates: 40, fat: 8)

        let halved = corrected.scaled(toWeightGrams: 75)
        expectClose(halved.calories, 150, "half of 150 g is half the calories")
        expectClose(halved.protein, 6)
        #expect(halved.isResolved)
    }

    @Test("resolving by hand does not erase that the portion was corrected")
    func manualResolutionKeepsTheCorrectionRecord() {
        let corrected = makeFood(weight: 200, calories: 0, resolved: false)
            .scaled(toWeightGrams: 150)
            .resolved(calories: 300, protein: 12, carbohydrates: 40, fat: 8)

        // §22 measures a correction against the model's first estimate; entering
        // nutrition is not a claim that the model estimated 150 g.
        #expect(corrected.wasPortionCorrected)
        expectClose(corrected.originalWeightGrams, 200)
    }

    @Test("confidence below 75% is flagged for checking")
    func lowConfidence() {
        #expect(makeFood(confidence: 0.74).isLowConfidence)
        #expect(!makeFood(confidence: 0.75).isLowConfidence)
    }

    @Test("correcting the weight rescales nutrition proportionally")
    func rescaling() {
        let corrected = makeFood(weight: 180, calories: 234).scaled(toWeightGrams: 90)
        expectClose(corrected.weightGrams, 90, "weight")
        expectClose(corrected.calories, 117, "calories")
        expectClose(corrected.protein, 2.15, "protein")
    }

    @Test("a correction is measured against the model's first estimate")
    func correctionIsTrackedAgainstTheOriginal() {
        let original = makeFood(weight: 180)
        #expect(!original.wasPortionCorrected)

        // Two successive edits must not compound — the second rescales from
        // 180 g, not from the already-halved 90 g.
        let once = original.scaled(toWeightGrams: 90)
        let twice = once.scaled(toWeightGrams: 180)
        #expect(once.wasPortionCorrected)
        expectClose(twice.calories, 234, "back to the original")
        expectClose(twice.originalWeightGrams, 180, "original is preserved")
    }

    @Test("zero weight does not divide by zero")
    func zeroWeight() {
        let corrected = makeFood(weight: 180).scaled(toWeightGrams: 0)
        expectClose(corrected.weightGrams, 0)
        expectClose(corrected.calories, 0)
    }

    @Test("a result needs attention when anything is unresolved or unsure")
    func needsAttention() {
        let confident = FoodAnalysisResult(foods: [makeFood()], provider: "mock")
        #expect(!confident.needsAttention)

        let unsure = FoodAnalysisResult(foods: [makeFood(confidence: 0.5)], provider: "mock")
        #expect(unsure.needsAttention)

        let unresolved = FoodAnalysisResult(foods: [makeFood(resolved: false)], provider: "mock")
        #expect(unresolved.needsAttention)
    }

    @Test("totals sum the foods")
    func totals() {
        let result = FoodAnalysisResult(
            foods: [makeFood(calories: 234), makeFood(calories: 90)],
            provider: "mock"
        )
        expectClose(result.totalCalories, 324)
    }

    @Test("confirming a food carries its confidence into the saved item")
    func becomesAFoodItem() {
        var food = makeFood(confidence: 0.86)
        food.nutritionSource = "usda_fdc"
        food.nutritionSourceID = "123"
        let item = food.scaled(toWeightGrams: 160).foodItem
        #expect(item.aiConfidence == 0.86)
        #expect(item.aiEstimatedWeightGrams == 180)
        #expect(item.wasPortionCorrected)
        #expect(item.nutritionSource == "usda_fdc")
        #expect(item.nutritionSourceID == "123")
        expectClose(item.calories, 208)
    }
}
