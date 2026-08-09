import Domain

@MainActor
func runBudgetChecks(_ runner: CheckRunner) {
    let useCase = EvaluateCalorieBudgetUseCase()

    func status(consumed: Double, target: Double = 2000) -> CalorieBudgetStatus {
        useCase.execute(budget: DailyCalorieBudget(target: target, consumed: consumed))
    }

    runner.check("budget/remaining-and-fraction") {
        let budget = DailyCalorieBudget(target: 2000, consumed: 1320)
        try expectClose(budget.remaining, 680, "remaining")
        try expectClose(budget.fractionUsed, 0.66, "fractionUsed")
    }

    runner.check("budget/remaining-goes-negative-past-target") {
        let budget = DailyCalorieBudget(target: 2000, consumed: 2180)
        try expectClose(budget.remaining, -180)
    }

    runner.check("budget/no-target-does-not-divide-by-zero") {
        let budget = DailyCalorieBudget(target: 0, consumed: 500)
        try expectClose(budget.fractionUsed, 0, "fractionUsed")
        try expect(useCase.execute(budget: budget), .normal, "status")
    }

    runner.check("budget/threshold-boundaries") {
        try expect(status(consumed: 0), .normal, "0%")
        try expect(status(consumed: 1399), .normal, "just under 70%")
        try expect(status(consumed: 1400), .informUser, "exactly 70%")
        try expect(status(consumed: 1799), .informUser, "just under 90%")
        try expect(status(consumed: 1800), .nearTarget, "exactly 90%")
        try expect(status(consumed: 1999), .nearTarget, "just under 100%")
        try expect(status(consumed: 2000), .reached, "exactly 100%")
        try expect(status(consumed: 2001), .exceeded, "just over 100%")
    }

    runner.check("budget/messages") {
        func message(consumed: Double) -> String? {
            useCase.message(for: DailyCalorieBudget(target: 2000, consumed: consumed))
        }
        try expect(message(consumed: 1000), nil, "below threshold")
        try expect(
            message(consumed: 1400),
            "You have 600 kcal remaining today.",
            "informUser"
        )
        try expect(
            message(consumed: 1800),
            "You're close to today's calorie target.",
            "nearTarget"
        )
        try expect(
            message(consumed: 2000),
            "You've reached today's calorie target.",
            "reached"
        )
        try expect(
            message(consumed: 2180),
            "You've exceeded today's target by 180 kcal.",
            "exceeded"
        )
    }
}
