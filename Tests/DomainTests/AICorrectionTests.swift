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

    /// The two types have to answer the same question the same way, or a rate
    /// computed on one side stops meaning what the other reports. They did not:
    /// `wasCorrected` on the proposal meant the portion alone while on the saved
    /// item it meant either half.
    @Test("a recognized food and the item it becomes agree on what a correction is")
    func bothTypesAgree() {
        var food = makeRecognized()
        food.name = "Bún bò Huế"
        let scaled = food.scaled(toWeightGrams: 420)
        let item = scaled.foodItem

        #expect(scaled.wasPortionCorrected == item.wasPortionCorrected)
        #expect(scaled.wasRenamed == item.wasRenamed)
        #expect(scaled.wasCorrected == item.wasCorrected)
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

    /// The other way a food reaches a meal without a prediction behind it: the
    /// user added it *inside the scan flow*, after the analysis failed or came
    /// back empty. It carries an `originalName` and an `originalWeightGrams`
    /// because those are `let` and always set — so if `foodItem` wrote them out
    /// regardless, the user's own first guess would be filed as the model's
    /// prediction and every §29 accuracy figure would count rows the model never
    /// saw.
    @Test("a food typed into the scan flow is not a prediction either")
    func handTypedFoodInTheScanFlowIsNotMeasured() {
        let typed = RecognizedFood.typedByHand()
            .resolved(calories: 320, protein: 12, carbohydrates: 40, fat: 11)
        var named = typed
        named.name = "Bánh cuốn"
        let item = named.scaled(toWeightGrams: 250).foodItem

        #expect(!named.isFromModel)
        #expect(item.aiConfidence == nil)
        #expect(item.aiEstimatedName == nil)
        #expect(item.aiEstimatedWeightGrams == nil)
        #expect(!item.cameFromScan)

        // Naming it and changing the portion are how it gets filled in at all,
        // so neither may read as a correction — on either type.
        #expect(!named.wasRenamed)
        #expect(!named.wasPortionCorrected)
        #expect(!named.wasCorrected)
        #expect(named.wasCorrected == named.foodItem.wasCorrected)
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
