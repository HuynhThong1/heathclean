/// Multiplies basal metabolic rate to give total daily energy expenditure.
public enum ActivityLevel: String, CaseIterable, Sendable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    public var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}
