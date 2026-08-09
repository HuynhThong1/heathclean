/// How far through the daily calorie budget the user is.
public enum CalorieBudgetStatus: String, CaseIterable, Sendable {
    /// Below 70% of the target.
    case normal
    /// 70% or more — worth telling the user what is left.
    case informUser
    /// 90% or more.
    case nearTarget
    /// Exactly at the target.
    case reached
    /// Past the target.
    case exceeded
}
