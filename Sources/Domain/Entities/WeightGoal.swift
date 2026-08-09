public enum WeightGoal: String, CaseIterable, Sendable {
    case lose
    case maintain
    case gain

    /// Daily energy offset applied to total daily energy expenditure.
    ///
    /// -500 kcal/day is roughly 0.45 kg of body weight per week; +350 kcal/day
    /// is a lean-gain surplus.
    public var dailyCalorieDelta: Double {
        switch self {
        case .lose: -500
        case .maintain: 0
        case .gain: 350
        }
    }

    /// Grams of protein per kilogram of body weight.
    ///
    /// A deficit raises the target to help preserve lean mass.
    public var proteinGramsPerKilogram: Double {
        switch self {
        case .lose: 1.8
        case .maintain, .gain: 1.6
        }
    }
}
