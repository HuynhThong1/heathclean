import Domain
import Foundation
import SwiftData

@ModelActor
actor SwiftDataMealRepository: MealRepository {
    func save(_ meal: Meal) async throws {
        modelContext.insert(MealEntity(meal: meal))
        try modelContext.save()
    }

    func meals(on date: Date) async throws -> [Meal] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(24 * 60 * 60)
        return try await meals(from: start, to: end)
    }

    func update(_ meal: Meal) async throws {
        let id = meal.id
        let descriptor = FetchDescriptor<MealEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try modelContext.fetch(descriptor).first else { return }

        // Rows are deleted and inserted by difference rather than the whole set
        // being replaced: reassigning `items` would leave the detached rows in the
        // store, since the cascade rule fires on deleting the *meal*, not on
        // dropping a child out of the relationship.
        let keep = Set(meal.items.map(\.id))
        for row in entity.items where !keep.contains(row.id) {
            modelContext.delete(row)
        }
        let existing = Set(entity.items.map(\.id))
        for item in meal.items where !existing.contains(item.id) {
            entity.items.append(FoodItemEntity(item: item))
        }

        // Photos are diffed the same way and for the same reason. Nothing in the
        // app edits them on a saved meal today — the scan attaches one at
        // creation — but reassigning the array would leave detached rows behind,
        // and an `update` that silently kept a removed photo would be a file the
        // sweep could never collect.
        let keepPhotos = Set(meal.photos.map(\.id))
        for row in entity.photos where !keepPhotos.contains(row.id) {
            modelContext.delete(row)
        }
        let existingPhotos = Set(entity.photos.map(\.id))
        for photo in meal.photos where !existingPhotos.contains(photo.id) {
            entity.photos.append(MealPhotoEntity(photo: photo))
        }

        entity.date = meal.date
        entity.typeRawValue = meal.type.rawValue
        // `calorieGoalWhenLogged` is deliberately not written here. It records what
        // the day was aiming for when the meal was logged, so editing a portion
        // cannot revise it — and an `update` that wrote it would let a caller
        // holding a hand-built `Meal` erase the only copy there is.
        try modelContext.save()
    }

    @discardableResult
    func delete(mealID: UUID) async throws -> [UUID] {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == mealID }
        )
        // The cascade rules on `items` and `photos` remove those rows with it;
        // the photo ids are read out first, because after the delete there is
        // nothing left to ask.
        var photoIDs: [UUID] = []
        for entity in try modelContext.fetch(descriptor) {
            photoIDs.append(contentsOf: entity.photos.map(\.id))
            modelContext.delete(entity)
        }
        try modelContext.save()
        return photoIDs
    }

    func photoIDs() async throws -> [UUID] {
        // Every row, once, at launch. Rows are four small fields, so this is
        // cheaper than it looks — and the alternative, trusting the filesystem,
        // is what leaves bytes behind.
        try modelContext.fetch(FetchDescriptor<MealPhotoEntity>()).map(\.id)
    }

    func meals(from start: Date, to end: Date) async throws -> [Meal] {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(\.meal)
    }

    func earliestMealDate() async throws -> Date? {
        // `fetchLimit` matters: this runs on every history page turn, and the
        // whole point of asking is to avoid reading meals that are not on screen.
        var descriptor = FetchDescriptor<MealEntity>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.date
    }
}
