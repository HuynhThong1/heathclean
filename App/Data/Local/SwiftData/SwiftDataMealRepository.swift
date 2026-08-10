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
