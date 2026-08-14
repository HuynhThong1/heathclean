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

    /// The day's calorie target, recorded at save time — see
    /// `Meal.calorieGoalWhenLogged`.
    ///
    /// Optional, and that is what makes this a lightweight migration: every meal
    /// already in the store gets `nil` and needs no conversion. A non-optional
    /// `Double` would need a default, and a default here is a *made-up target* on
    /// days the app never knew one for — which is the figure history is supposed to
    /// stop inventing.
    var calorieGoalWhenLogged: Double?

    init(meal: Meal) {
        self.id = meal.id
        self.date = meal.date
        self.typeRawValue = meal.type.rawValue
        self.items = meal.items.map(FoodItemEntity.init(item:))
        self.photos = meal.photos.map(MealPhotoEntity.init(photo:))
        self.calorieGoalWhenLogged = meal.calorieGoalWhenLogged
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
                .map(\.mealPhoto),
            calorieGoalWhenLogged: calorieGoalWhenLogged
        )
    }
}
