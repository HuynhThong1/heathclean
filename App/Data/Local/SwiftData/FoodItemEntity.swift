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

    /// Always `nil` for manual entry; populated once meal photo analysis lands.
    var aiConfidence: Double?
    var aiEstimatedWeightGrams: Double?

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
        self.aiConfidence = item.aiConfidence
        self.aiEstimatedWeightGrams = item.aiEstimatedWeightGrams
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
            aiConfidence: aiConfidence,
            aiEstimatedWeightGrams: aiEstimatedWeightGrams,
            nutritionSource: nutritionSource,
            nutritionSourceID: nutritionSourceID,
            nutritionSourceURL: nutritionSourceURL,
            nutritionIsReference: nutritionIsReference
        )
    }
}
