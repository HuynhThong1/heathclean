import Foundation

public protocol MealRepository: Sendable {
    func save(_ meal: Meal) async throws

    /// Meals whose `date` falls on the same calendar day as `date`.
    func meals(on date: Date) async throws -> [Meal]

    /// Meals in the half-open interval `[start, end)`.
    func meals(from start: Date, to end: Date) async throws -> [Meal]

    /// The date of the oldest logged meal, or `nil` when nothing is logged.
    ///
    /// The month grid (§32) pages backwards, and the store can always answer for
    /// one more month — an empty one. Without a floor, "load more" would page
    /// into empty months for ever, so this is what tells the screen there is
    /// nothing older to reach. One row, not a scan.
    func earliestMealDate() async throws -> Date?

    /// Replaces a stored meal's contents. Needed to remove one food from a meal
    /// without discarding the rest of it; `save` inserts, so it cannot do this.
    /// Updating an id that is not stored is not an error.
    func update(_ meal: Meal) async throws

    /// Removes a logged meal and everything in it. Deleting an id that is not
    /// stored is not an error — the end state is the same either way.
    ///
    /// Returns the ids of the photos that went with it, so the caller can delete
    /// the files (§32.4). The rows are the store's to cascade; the bytes are
    /// not — and the answer comes from what was actually removed rather than
    /// from the caller's copy of the meal, which may predate a photo.
    @discardableResult
    func delete(mealID: UUID) async throws -> [UUID]

    /// Every photo id any stored meal still refers to.
    ///
    /// The launch-time orphan sweep is the only caller: a file whose row is gone
    /// is bytes nothing can ever show again, and the two are written separately
    /// on purpose, so something has to reconcile them.
    func photoIDs() async throws -> [UUID]
}
