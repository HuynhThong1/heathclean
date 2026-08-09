/// The warning engine. Language stays neutral and informative — never
/// instructional about whether the user should eat.
public struct EvaluateCalorieBudgetUseCase: Sendable {
    public init() {}

    public func execute(budget: DailyCalorieBudget) -> CalorieBudgetStatus {
        let fraction = budget.fractionUsed

        if fraction > 1 { return .exceeded }
        if fraction >= 1 { return .reached }
        if fraction >= 0.9 { return .nearTarget }
        if fraction >= 0.7 { return .informUser }
        return .normal
    }

    /// `nil` below the first threshold — there is nothing worth saying yet.
    public func message(for budget: DailyCalorieBudget) -> String? {
        let magnitude = Int(abs(budget.remaining).rounded())

        switch execute(budget: budget) {
        case .normal:
            return nil
        case .informUser:
            return "You have \(magnitude) kcal remaining today."
        case .nearTarget:
            return "You're close to today's calorie target."
        case .reached:
            return "You've reached today's calorie target."
        case .exceeded:
            return "You've exceeded today's target by \(magnitude) kcal."
        }
    }
}
