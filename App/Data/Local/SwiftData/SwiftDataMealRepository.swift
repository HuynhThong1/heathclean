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

        entity.date = meal.date
        entity.typeRawValue = meal.type.rawValue
        try modelContext.save()
    }

    func delete(mealID: UUID) async throws {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == mealID }
        )
        // The cascade rule on `items` removes the food rows with it.
        for entity in try modelContext.fetch(descriptor) {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    func meals(from start: Date, to end: Date) async throws -> [Meal] {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(\.meal)
    }
}
