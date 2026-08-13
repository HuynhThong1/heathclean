import Domain
import Foundation
import SwiftData

/// Photo metadata for a stored meal. The bytes live in `MealPhotoStore`; this row
/// only knows the id that names them (§32.4).
///
/// Added after the store shipped, so **every property has to make sense as a
/// default for a meal that predates it.** There is nothing to default here — old
/// meals simply have no rows — which is what makes this a lightweight migration:
/// a new model plus a to-many relationship that starts empty.
@Model
final class MealPhotoEntity {
    var id: UUID
    var capturedAt: Date
    var pixelWidth: Int
    var pixelHeight: Int

    /// Optional because SwiftData requires the inverse side of a relationship to
    /// be nullable; a photo without a meal is an orphan the sweep collects.
    var meal: MealEntity?

    init(photo: MealPhoto) {
        self.id = photo.id
        self.capturedAt = photo.capturedAt
        self.pixelWidth = photo.pixelWidth
        self.pixelHeight = photo.pixelHeight
    }
}

extension MealPhotoEntity {
    var mealPhoto: MealPhoto {
        MealPhoto(
            id: id,
            capturedAt: capturedAt,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )
    }
}
