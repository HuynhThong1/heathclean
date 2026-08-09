import Foundation

public protocol MealRepository: Sendable {
    func save(_ meal: Meal) async throws

    /// Meals whose `date` falls on the same calendar day as `date`.
    func meals(on date: Date) async throws -> [Meal]

    /// Meals in the half-open interval `[start, end)`.
    func meals(from start: Date, to end: Date) async throws -> [Meal]
}
