import Foundation

public struct Meal: Sendable, Equatable, Identifiable {
    public let id: UUID

    public var date: Date
    public var type: MealType
    public var items: [FoodItem]

    public init(id: UUID = UUID(), date: Date, type: MealType, items: [FoodItem]) {
        self.id = id
        self.date = date
        self.type = type
        self.items = items
    }

    public var calories: Double { items.reduce(0) { $0 + $1.calories } }
    public var protein: Double { items.reduce(0) { $0 + $1.protein } }
    public var carbohydrates: Double { items.reduce(0) { $0 + $1.carbohydrates } }
    public var fat: Double { items.reduce(0) { $0 + $1.fat } }
}
