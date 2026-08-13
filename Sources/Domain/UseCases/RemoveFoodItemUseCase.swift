import Foundation

/// Removes one food from a logged meal.
///
/// The rule worth having in one place: **a meal with nothing left in it is
/// deleted, not stored empty.** `SaveMealUseCase` refuses to create a meal with
/// no items (`MealValidationError.noItems`), so leaving one behind by deletion
/// would put a row in storage that the app would never have accepted — it would
/// show up in history as a 0 kcal meal that cannot be explained.
public struct RemoveFoodItemUseCase: Sendable {
    private let mealRepository: any MealRepository

    public init(mealRepository: any MealRepository) {
        self.mealRepository = mealRepository
    }

    /// What happened, so the caller knows whether the meal it was showing still
    /// exists and can leave the screen rather than render an empty one.
    public enum Outcome: Equatable, Sendable {
        case itemRemoved(Meal)
        /// Carries the photo ids the store removed with the meal, so the caller
        /// can delete their files — the same contract as
        /// `MealRepository.delete(mealID:)`, and for the same reason: what the
        /// store actually removed beats what the caller's copy of the meal knew
        /// about (§32.4).
        case mealDeleted(photoIDs: [UUID])
        /// The item was not in this meal. Not an error: the end state is what the
        /// caller wanted either way.
        case notFound
    }

    @discardableResult
    public func execute(itemID: UUID, from meal: Meal) async throws -> Outcome {
        guard meal.items.contains(where: { $0.id == itemID }) else { return .notFound }

        var updated = meal
        updated.items.removeAll { $0.id == itemID }

        if updated.items.isEmpty {
            let photoIDs = try await mealRepository.delete(mealID: meal.id)
            return .mealDeleted(photoIDs: photoIDs)
        }

        try await mealRepository.update(updated)
        return .itemRemoved(updated)
    }
}
