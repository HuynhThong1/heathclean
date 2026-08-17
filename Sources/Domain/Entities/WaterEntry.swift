import Foundation

/// One drink. `plan.md` Phase 5's "optional water tracking".
///
/// **Water is not a food, so it is not a `FoodItem`.** It carries no energy, it
/// is not part of a meal, and putting it in one would drag it into every
/// calorie and macro total in the app — `Meal.calories` would have to learn to
/// skip it, and so would the history bar, the budget engine and §22's rates. It
/// is a log beside the day, the same shape as `WeightEntry` beside the profile.
///
/// Millilitres rather than glasses: a glass is not a unit, and the moment two
/// screens disagree about how big one is the total stops meaning anything.
/// `WaterServing` names the sizes the UI offers.
public struct WaterEntry: Sendable, Equatable, Identifiable {
    public let id: UUID

    public var date: Date
    public var millilitres: Double

    public init(id: UUID = UUID(), date: Date, millilitres: Double) {
        self.id = id
        self.date = date
        self.millilitres = millilitres
    }
}

/// The quick-add sizes, in millilitres.
///
/// In Domain rather than in the view because the *figures* are the product
/// decision — how much a tap is worth — while what they are called on screen is
/// not. The names live in `DisplayCopy`, like every other Domain value's.
public enum WaterServing: Double, CaseIterable, Sendable {
    case glass = 250
    case bottle = 500

    public var millilitres: Double { rawValue }
}
