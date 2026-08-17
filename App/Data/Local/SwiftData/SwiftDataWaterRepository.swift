import Domain
import Foundation
import SwiftData

@ModelActor
actor SwiftDataWaterRepository: WaterRepository {
    func log(_ entry: WaterEntry) async throws {
        modelContext.insert(WaterEntryEntity(entry: entry))
        try modelContext.save()
    }

    func entries(from start: Date, to end: Date) async throws -> [WaterEntry] {
        let descriptor = FetchDescriptor<WaterEntryEntity>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(\.entry)
    }

    /// Deleting something that is already gone is not an error: undo can be
    /// tapped twice, and the second tap should find the day unchanged rather
    /// than throw.
    ///
    /// **The captured value is renamed before it reaches `#Predicate`.** Written
    /// as `$0.id == id` the macro has two things called `id` in scope — the
    /// model's property and the argument — and it resolves the comparison to
    /// something that matches nothing, so undo silently deleted no row and the
    /// total never moved. `SwiftDataMealRepository` never hit this because its
    /// parameter happens to be called `mealID`.
    func delete(id: UUID) async throws {
        let entryID = id
        let all = try modelContext.fetch(FetchDescriptor<WaterEntryEntity>())
        guard let entity = all.first(where: { $0.id == entryID }) else { return }
        modelContext.delete(entity)
        try modelContext.save()
    }
}
