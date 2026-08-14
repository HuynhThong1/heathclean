import Foundation

public struct Meal: Sendable, Equatable, Identifiable {
    public let id: UUID

    public var date: Date
    public var type: MealType
    public var items: [FoodItem]

    /// Oldest first. Empty for every manually entered meal and for everything
    /// logged before §32 stage 2 — a meal without a photo is a normal meal, not
    /// an incomplete one, which is why this defaults to `[]` rather than being
    /// required.
    public var photos: [MealPhoto]

    /// The daily calorie target that was in force when this meal was logged.
    ///
    /// **History needs the target of the day, not today's.** `UserProfile` holds
    /// one current goal that an edit overwrites, so without this every past day's
    /// deviation bar moved when the user changed their goal — HISTORY_SPEC §8's one
    /// unmet requirement. Recording it here is what fixes it: the figure a day is
    /// judged against is a fact about that day, so it is stored with the day's data
    /// rather than recomputed from state that has since changed.
    ///
    /// `nil` for every meal logged before this field existed, and for one saved
    /// while the profile could not be read. A missing stamp is not zero — zero is a
    /// target of no calories — so readers fall back to the current goal and
    /// `HistoryDay.goalCalories` keeps the two apart.
    ///
    /// `SaveMealUseCase` is the only writer. An edit to a saved meal never changes
    /// it: what the day was aiming for is not something changing a portion revises.
    public var calorieGoalWhenLogged: Double?

    public init(
        id: UUID = UUID(),
        date: Date,
        type: MealType,
        items: [FoodItem],
        photos: [MealPhoto] = [],
        calorieGoalWhenLogged: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.items = items
        self.photos = photos
        self.calorieGoalWhenLogged = calorieGoalWhenLogged
    }

    public var calories: Double { items.reduce(0) { $0 + $1.calories } }
    public var protein: Double { items.reduce(0) { $0 + $1.protein } }
    public var carbohydrates: Double { items.reduce(0) { $0 + $1.carbohydrates } }
    public var fat: Double { items.reduce(0) { $0 + $1.fat } }
}
