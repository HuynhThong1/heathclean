import Domain
import Foundation
import Testing

/// §22 stores what the model proposed beside what the user confirmed, and §29
/// measures accuracy from it. These pin the half that is easy to destroy by
/// accident: the *original*, which nothing may write to after the gateway
/// answered.
@Suite("AI correction record")
struct AICorrectionTests {
    private func makeRecognized(name: String = "Phở bò", weight: Double = 350)
        -> RecognizedFood
    {
        RecognizedFood(
            name: name,
            weightGrams: weight,
            calories: 480,
            protein: 30,
            carbohydrates: 55,
            fat: 12,
            confidence: 0.98,
            isResolved: true
        )
    }

    // MARK: The original survives every edit

    @Test("renaming keeps what the model called it")
    func renamingKeepsTheOriginal() {
        var food = makeRecognized()
        #expect(!food.wasRenamed)

        // The real miss this exists for: bún bò Huế came back as "Phở bò" at
        // 0.98, which no confidence threshold catches. The only trace is this.
        food.name = "Bún bò Huế"

        #expect(food.originalName == "Phở bò")
        #expect(food.wasRenamed)
    }

    @Test("rescaling the portion does not disturb the name")
    func scalingKeepsTheOriginalName() {
        var food = makeRecognized()
        food.name = "Bún bò Huế"
        let scaled = food.scaled(toWeightGrams: 500)

        #expect(scaled.originalName == "Phở bò")
        #expect(scaled.wasRenamed)
    }

    /// The trap `originalWeightGrams` already documents, in its other half:
    /// hand-entering nutrition must not quietly reset what is being measured.
    @Test("supplying nutrition does not disturb the name either")
    func resolvingKeepsTheOriginalName() {
        var food = makeRecognized(name: "Bánh canh")
        food.name = "Bánh canh cua"
        let fixed = food.resolved(calories: 400, protein: 20, carbohydrates: 50, fat: 10)

        #expect(fixed.originalName == "Bánh canh")
        #expect(fixed.wasRenamed)
    }

    // MARK: What counts as a rename

    @Test(
        "typing the same dish differently is not the model being wrong",
        arguments: [
            "Pho bo",  // no tone marks
            "PHỞ BÒ",  // shouting
            "  Phở bò  ",  // stray whitespace
            "phở bò",
        ]
    )
    func foldedComparisons(typed: String) {
        var food = makeRecognized()
        food.name = typed
        #expect(!food.wasRenamed, "\"\(typed)\" is the same dish as \"Phở bò\"")
    }

    // MARK: Crossing into a saved meal

    @Test("confirming carries both originals into the stored item")
    func confirmingCarriesBothOriginals() {
        var food = makeRecognized(weight: 350)
        food.name = "Bún bò Huế"
        let item = food.scaled(toWeightGrams: 420).foodItem

        #expect(item.aiEstimatedName == "Phở bò")
        expectClose(item.aiEstimatedWeightGrams ?? 0, 350)
        #expect(item.cameFromScan)
        #expect(item.wasRenamed)
        #expect(item.wasPortionCorrected)
        #expect(item.wasCorrected)
    }

    @Test("a scan the user accepted as-is counts as no correction")
    func acceptedScanIsNotACorrection() {
        let item = makeRecognized().foodItem

        #expect(item.cameFromScan)
        #expect(!item.wasRenamed)
        #expect(!item.wasPortionCorrected)
        #expect(!item.wasCorrected)
    }

    /// A typed meal has no prediction to be right or wrong about, so it is not in
    /// any §22 denominator — `cameFromScan` is what keeps it out.
    @Test("a hand-typed food is not part of the measurement at all")
    func manualEntryIsNotMeasured() {
        let item = makeFoodItem(name: "Cơm trắng")

        #expect(!item.cameFromScan)
        #expect(!item.wasRenamed)
        #expect(!item.wasPortionCorrected)
        #expect(!item.wasCorrected)
    }

    /// Rows written before the field existed read back `nil`, and `nil` is "not
    /// recorded" — never "the model was right", which would quietly count old
    /// meals as successes.
    @Test("an item from before the field was added reports no correction")
    func unrecordedNameIsNotASuccess() {
        let item = FoodItem(
            name: "Phở bò",
            weightGrams: 350,
            calories: 480,
            protein: 30,
            carbohydrates: 55,
            fat: 12,
            aiConfidence: 0.98,
            aiEstimatedWeightGrams: 350,
            aiEstimatedName: nil
        )

        #expect(item.cameFromScan)
        #expect(!item.wasRenamed)
    }
}
