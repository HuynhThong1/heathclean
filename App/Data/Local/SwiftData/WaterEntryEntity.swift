import Domain
import Foundation
import SwiftData

/// One drink. A new model rather than a new attribute, so the migration stays
/// lightweight — the same shape `MealPhotoEntity` took.
@Model
final class WaterEntryEntity {
    var id: UUID
    var date: Date
    var millilitres: Double

    init(entry: WaterEntry) {
        self.id = entry.id
        self.date = entry.date
        self.millilitres = entry.millilitres
    }
}

extension WaterEntryEntity {
    var entry: WaterEntry {
        WaterEntry(id: id, date: date, millilitres: millilitres)
    }
}
