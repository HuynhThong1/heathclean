import Foundation

public protocol MealRepository: Sendable {
    func save(_ meal: Meal) async throws

    /// Meals whose `date` falls on the same calendar day as `date`.
    func meals(on date: Date) async throws -> [Meal]

    /// Meals in the half-open interval `[start, end)`.
    func meals(from start: Date, to end: Date) async throws -> [Meal]

    /// Removes a logged meal and everything in it. Deleting an id that is not
    /// stored is not an error — the end state is the same either way.
    func delete(mealID: UUID) async throws
}
