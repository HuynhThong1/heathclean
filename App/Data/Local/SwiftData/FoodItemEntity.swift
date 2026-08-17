import Domain
import Foundation
import SwiftData

@Model
final class FoodItemEntity {
    var id: UUID
    var name: String
    var weightGrams: Double

    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double

    /// Grams of fibre, or `nil` where nobody measured it.
    ///
    /// The fourth lightweight migration in this store, and the same shape as
    /// the previous three: a new optional attribute, so every row written
    /// before it reads back `nil` and needs no conversion. Here the optional is
    /// not merely convenient — `nil` and `0` are different facts, and
    /// `FoodItem.fiber` documents why. A non-optional column would need a
    /// default, and the only available default would claim every meal ever
    /// logged contained no fibre.
    var fiber: Double?

    /// Always `nil` for manual entry; populated by the scan.
    ///
    /// `aiEstimatedName` is the third lightweight migration in this store (after
    /// `MealPhotoEntity` and `MealEntity.calorieGoalWhenLogged`) and the same
    /// shape as the second: a new optional attribute, so rows written before it
    /// read back as `nil` and need no conversion. `nil` here means "not recorded",
    /// which `FoodItem.wasRenamed` reads as "no correction to report" rather than
    /// as "the model was right".
    var aiConfidence: Double?
    var aiEstimatedWeightGrams: Double?
    var aiEstimatedName: String?

    var nutritionSource: String?
    var nutritionSourceID: String?
    var nutritionSourceURL: String?
    var nutritionIsReference: Bool = false

    var meal: MealEntity?

    init(item: FoodItem) {
        self.id = item.id
        self.name = item.name
        self.weightGrams = item.weightGrams
        self.calories = item.calories
        self.protein = item.protein
        self.carbohydrates = item.carbohydrates
        self.fat = item.fat
        self.fiber = item.fiber
        self.aiConfidence = item.aiConfidence
        self.aiEstimatedWeightGrams = item.aiEstimatedWeightGrams
        self.aiEstimatedName = item.aiEstimatedName
        self.nutritionSource = item.nutritionSource
        self.nutritionSourceID = item.nutritionSourceID
        self.nutritionSourceURL = item.nutritionSourceURL
        self.nutritionIsReference = item.nutritionIsReference
    }
}

extension FoodItemEntity {
    var foodItem: FoodItem {
        FoodItem(
            id: id,
            name: name,
            weightGrams: weightGrams,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            fiber: fiber,
            aiConfidence: aiConfidence,
            aiEstimatedWeightGrams: aiEstimatedWeightGrams,
            aiEstimatedName: aiEstimatedName,
            nutritionSource: nutritionSource,
            nutritionSourceID: nutritionSourceID,
            nutritionSourceURL: nutritionSourceURL,
            nutritionIsReference: nutritionIsReference
        )
    }
}
