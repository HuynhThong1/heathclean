import Foundation

/// One weighing. `UserProfile.weightKg` is the current value the calorie model
/// reads; this is the history behind it, which the profile cannot hold.
public struct WeightEntry: Sendable, Equatable, Identifiable {
    public let id: UUID

    public var date: Date
    public var kilograms: Double

    public init(id: UUID = UUID(), date: Date, kilograms: Double) {
        self.id = id
        self.date = date
        self.kilograms = kilograms
    }
}
