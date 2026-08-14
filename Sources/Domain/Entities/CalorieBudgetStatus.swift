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

extension CalorieBudgetStatus: Comparable {
    /// The rungs of the warning engine's ladder, in the order
    /// `EvaluateCalorieBudgetUseCase` climbs them.
    ///
    /// This is what lets a caller ask "has the day moved *up* since I last
    /// said something" — which is the whole of the notification rule (§19), and
    /// which `CaseIterable`'s declaration order cannot answer without being read
    /// as an accident.
    private var rank: Int {
        switch self {
        case .normal: 0
        case .informUser: 1
        case .nearTarget: 2
        case .reached: 3
        case .exceeded: 4
        }
    }

    public static func < (lhs: CalorieBudgetStatus, rhs: CalorieBudgetStatus) -> Bool {
        lhs.rank < rhs.rank
    }
}
