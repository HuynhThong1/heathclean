import Domain
import Foundation
import SwiftData

@Model
final class MealEntity {
    var id: UUID
    var date: Date
    var typeRawValue: String

    @Relationship(deleteRule: .cascade, inverse: \FoodItemEntity.meal)
    var items: [FoodItemEntity]

    init(meal: Meal) {
        self.id = meal.id
        self.date = meal.date
        self.typeRawValue = meal.type.rawValue
        self.items = meal.items.map(FoodItemEntity.init(item:))
    }
}

extension MealEntity {
    var meal: Meal {
        Meal(
            id: id,
            date: date,
            type: MealType(rawValue: typeRawValue) ?? .snack,
            items: items.map(\.foodItem)
        )
    }
}
