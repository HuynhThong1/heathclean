public enum BMICategory: String, CaseIterable, Sendable {
    case underweight
    case normal
    case overweight
    case obese
}

/// Body mass index, treated as health context only.
///
/// The daily calorie target is never derived from this value — see
/// `CalculateCalorieGoalUseCase`.
public struct BMI: Sendable, Equatable {
    public let value: Double

    public init(value: Double) {
        self.value = value
    }

    /// World Health Organization cutoffs.
    public var category: BMICategory {
        switch value {
        case ..<18.5: .underweight
        case ..<25: .normal
        case ..<30: .overweight
        default: .obese
        }
    }
}
