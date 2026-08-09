let runner = CheckRunner()

runBMIChecks(runner)
runCalorieGoalChecks(runner)
runBudgetChecks(runner)
await runMealChecks(runner)

runner.finish()
