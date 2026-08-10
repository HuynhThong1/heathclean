import Domain
import Foundation
import SwiftData

@ModelActor
actor SwiftDataWeightRepository: WeightRepository {
    func log(_ entry: WeightEntry) async throws {
        modelContext.insert(WeightEntryEntity(entry: entry))
        try modelContext.save()
    }

    func entries(from start: Date, to end: Date) async throws -> [WeightEntry] {
        let descriptor = FetchDescriptor<WeightEntryEntity>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(\.entry)
    }

    func latest() async throws -> WeightEntry? {
        var descriptor = FetchDescriptor<WeightEntryEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.entry
    }
}
