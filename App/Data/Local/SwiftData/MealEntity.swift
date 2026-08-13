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

    /// Cascades like `items`: deleting a meal takes its photo rows with it. The
    /// *files* are a separate step, because the store cannot reach them —
    /// `SwiftDataMealRepository.delete` returns the ids for that (§32.4).
    @Relationship(deleteRule: .cascade, inverse: \MealPhotoEntity.meal)
    var photos: [MealPhotoEntity]

    init(meal: Meal) {
        self.id = meal.id
        self.date = meal.date
        self.typeRawValue = meal.type.rawValue
        self.items = meal.items.map(FoodItemEntity.init(item:))
        self.photos = meal.photos.map(MealPhotoEntity.init(photo:))
    }
}

extension MealEntity {
    var meal: Meal {
        Meal(
            id: id,
            date: date,
            type: MealType(rawValue: typeRawValue) ?? .snack,
            items: items.map(\.foodItem),
            // A SwiftData relationship is a set with no order of its own, and
            // §32.3 needs the day's picture to be the same on every render — so
            // the order is stated here rather than inherited. `id` breaks the tie
            // when two photos share a timestamp.
            photos: photos
                .sorted { ($0.capturedAt, $0.id.uuidString) < ($1.capturedAt, $1.id.uuidString) }
                .map(\.mealPhoto)
        )
    }
}
