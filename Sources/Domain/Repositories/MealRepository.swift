import Foundation

public protocol MealRepository: Sendable {
    func save(_ meal: Meal) async throws

    /// Meals whose `date` falls on the same calendar day as `date`.
    func meals(on date: Date) async throws -> [Meal]

    /// Meals in the half-open interval `[start, end)`.
    func meals(from start: Date, to end: Date) async throws -> [Meal]

    /// Replaces a stored meal's contents. Needed to remove one food from a meal
    /// without discarding the rest of it; `save` inserts, so it cannot do this.
    /// Updating an id that is not stored is not an error.
    func update(_ meal: Meal) async throws

    /// Removes a logged meal and everything in it. Deleting an id that is not
    /// stored is not an error — the end state is the same either way.
    func delete(mealID: UUID) async throws
}
