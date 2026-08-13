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

    public init(
        id: UUID = UUID(),
        date: Date,
        type: MealType,
        items: [FoodItem],
        photos: [MealPhoto] = []
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.items = items
        self.photos = photos
    }

    public var calories: Double { items.reduce(0) { $0 + $1.calories } }
    public var protein: Double { items.reduce(0) { $0 + $1.protein } }
    public var carbohydrates: Double { items.reduce(0) { $0 + $1.carbohydrates } }
    public var fat: Double { items.reduce(0) { $0 + $1.fat } }
}
