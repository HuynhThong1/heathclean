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
            aiConfidence: aiConfidence
        )
    }
}
