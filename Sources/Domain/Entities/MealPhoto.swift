import Foundation

/// A photo of a logged meal, as far as Domain is concerned: an identity, when it
/// was taken, and how big it is.
///
/// **There is deliberately no path, URL or image data here** (§32.4). Domain
/// imports only the standard library and Foundation, so it has no `UIImage` to
/// hold; and a file path is a fact about one installation of the app, not about
/// the meal. `MealPhotoStore` in the App layer maps `id` to bytes, which is what
/// lets the same meal be readable when the bytes are gone — a restored backup, a
/// file the user's device lost — instead of turning a missing file into a
/// missing meal.
public struct MealPhoto: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var capturedAt: Date
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(
        id: UUID = UUID(),
        capturedAt: Date,
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}
