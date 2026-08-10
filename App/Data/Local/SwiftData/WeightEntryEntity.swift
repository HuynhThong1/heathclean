import Domain
import Foundation
import SwiftData

@Model
final class WeightEntryEntity {
    var id: UUID
    var date: Date
    var kilograms: Double

    init(entry: WeightEntry) {
        self.id = entry.id
        self.date = entry.date
        self.kilograms = entry.kilograms
    }
}

extension WeightEntryEntity {
    var entry: WeightEntry {
        WeightEntry(id: id, date: date, kilograms: kilograms)
    }
}
