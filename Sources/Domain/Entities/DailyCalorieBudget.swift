public struct DailyCalorieBudget: Sendable, Equatable {
    public let target: Double
    public let consumed: Double

    public init(target: Double, consumed: Double) {
        self.target = target
        self.consumed = consumed
    }

    /// Negative once the target is exceeded.
    public var remaining: Double {
        target - consumed
    }

    /// Zero when no target has been set, so callers never see a division by zero.
    public var fractionUsed: Double {
        target > 0 ? consumed / target : 0
    }
}
