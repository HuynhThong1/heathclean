import XCTest

/// Walks the Phase 1 flow the way a user would: onboarding produces a target,
/// a logged meal moves the dashboard, and crossing a threshold surfaces the
/// warning copy.
///
/// Assertions avoid locale-formatted numbers — the app renders calorie totals
/// with plain integer interpolation, but grouped values like "2.378 kcal" vary
/// by the simulator's region.
final class Phase1FlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testOnboardingProducesTargetsAndReachesDashboard() {
        XCTAssertTrue(app.navigationBars["Set up"].waitForExistence(timeout: 30))

        // Defaults are 170 cm, 70 kg, 30 y, unspecified sex, moderate, maintain
        // → BMR 1534.5 × 1.55 = 2378 kcal, protein 70 × 1.6 = 112 g.
        XCTAssertTrue(app.staticTexts["Protein, 112 g"].exists)

        app.buttons["Continue"].tap()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["0 kcal eaten"].exists)
        XCTAssertTrue(app.staticTexts["\(kcal(2378)) kcal remaining"].exists)
    }

    func testLoggingAMealMovesTheDashboard() {
        reachDashboard()

        logMeal(named: "breakfast", food: "Porridge", calories: 500)

        XCTAssertTrue(app.staticTexts["500 kcal eaten"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["\(kcal(1878)) kcal remaining"].exists)
        XCTAssertTrue(app.buttons["mealRow.breakfast"].label.contains("500 kcal"))
    }

    func testCrossingSeventyPercentShowsTheInformMessage() {
        reachDashboard()

        // 70% of 2378 is 1664.6, so 1700 kcal crosses it.
        logMeal(named: "lunch", food: "Big lunch", calories: 1700)

        XCTAssertTrue(
            app.staticTexts["You have 678 kcal remaining today."].waitForExistence(timeout: 30)
        )
    }

    func testExceedingTheTargetReportsTheOverage() {
        reachDashboard()

        logMeal(named: "dinner", food: "Feast", calories: 2500)

        XCTAssertTrue(
            app.staticTexts["You've exceeded today's target by 122 kcal."]
                .waitForExistence(timeout: 30)
        )
    }

    // MARK: Helpers

    private func reachDashboard() {
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 30))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 30))
    }

    private func logMeal(named meal: String, food: String, calories: Int) {
        app.buttons["mealRow.\(meal)"].tap()

        let name = app.textFields["field.food"]
        XCTAssertTrue(name.waitForExistence(timeout: 30))
        name.tap()
        name.typeText(food)

        // Number fields start populated and tapping puts the caret at the
        // start, so select the existing value rather than trying to backspace.
        let caloriesField = app.textFields["field.calories"]
        caloriesField.doubleTap()
        caloriesField.typeText("\(calories)")

        app.buttons["Save"].tap()
    }

    /// Totals are rendered with locale grouping, so build the expected string
    /// the same way instead of hardcoding one region's separators.
    private func kcal(_ value: Int) -> String {
        value.formatted()
    }
}
