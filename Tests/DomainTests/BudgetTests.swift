import Domain
import Testing

@Suite("Calorie budget")
struct BudgetTests {
    let useCase = EvaluateCalorieBudgetUseCase()

    private func status(consumed: Double, target: Double = 2000) -> CalorieBudgetStatus {
        useCase.execute(budget: DailyCalorieBudget(target: target, consumed: consumed))
    }

    private func message(consumed: Double) -> String? {
        useCase.message(for: DailyCalorieBudget(target: 2000, consumed: consumed))
    }

    @Test("reports what is left")
    func remainingAndFraction() {
        let budget = DailyCalorieBudget(target: 2000, consumed: 1320)
        expectClose(budget.remaining, 680, "remaining")
        expectClose(budget.fractionUsed, 0.66, "fractionUsed")
    }

    @Test("remaining goes negative past the target")
    func remainingGoesNegative() {
        expectClose(DailyCalorieBudget(target: 2000, consumed: 2180).remaining, -180)
    }

    @Test("no target does not divide by zero")
    func noTarget() {
        let budget = DailyCalorieBudget(target: 0, consumed: 500)
        expectClose(budget.fractionUsed, 0)
        #expect(useCase.execute(budget: budget) == .normal)
    }

    @Test(
        "thresholds land on the documented boundaries",
        arguments: [
            (0.0, CalorieBudgetStatus.normal),
            (1399.0, .normal),
            (1400.0, .informUser),
            (1799.0, .informUser),
            (1800.0, .nearTarget),
            (1999.0, .nearTarget),
            (2000.0, .reached),
            (2001.0, .exceeded)
        ]
    )
    func thresholdBoundaries(consumed: Double, expected: CalorieBudgetStatus) {
        #expect(status(consumed: consumed) == expected)
    }

    @Test("stays quiet below the first threshold")
    func noMessageEarly() {
        #expect(message(consumed: 1000) == nil)
    }

    @Test(
        "messages are neutral and informative",
        arguments: [
            (1400.0, "You have 600 kcal remaining today."),
            (1800.0, "You're close to today's calorie target."),
            (2000.0, "You've reached today's calorie target."),
            (2180.0, "You've exceeded today's target by 180 kcal.")
        ]
    )
    func messages(consumed: Double, expected: String) {
        #expect(message(consumed: consumed) == expected)
    }
}
