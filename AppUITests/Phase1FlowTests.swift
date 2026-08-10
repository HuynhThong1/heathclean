import XCTest

/// Walks the Phase 1 flow the way a user would: onboarding produces a target,
/// a logged meal moves the dashboard, and crossing a threshold surfaces the
/// status note.
///
/// The dashboard follows the design handoff (§6.4) and is Vietnamese-primary,
/// so its assertions are Vietnamese. Onboarding has not been converted yet and
/// is still English.
///
/// Numbers are built with a `vi_VN` formatter rather than hardcoded, because
/// the app formats with that locale regardless of the device's.
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

        XCTAssertTrue(app.buttons["mealRow.breakfast"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["hero.remaining"].label, "\(vn(2378)) kcal còn lại")
    }

    func testOutOfRangeWeightExplainsWhyContinueIsDisabled() {
        XCTAssertTrue(app.navigationBars["Set up"].waitForExistence(timeout: 30))

        let weight = app.textFields["field.weight"]
        weight.doubleTap()
        weight.typeText("500")
        // `TextField(value:format:)` commits on end-editing, so move focus off.
        app.staticTexts["Height"].tap()

        // DSFieldMessage prefixes its accessibility label with "Error: " so
        // VoiceOver distinguishes an error from a hint.
        XCTAssertTrue(
            app.staticTexts["Error: Enter a weight between 25 and 400 kg"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.buttons["Continue"].isEnabled)

        // The targets are derived from weight, so they must not be shown at all
        // rather than shown as confident nonsense.
        XCTAssertTrue(app.staticTexts["Targets unavailable"].exists)
        XCTAssertFalse(app.staticTexts["kcal per day"].exists)
    }

    func testLoggingAMealMovesTheDashboard() {
        reachDashboard()

        logMeal(named: "breakfast", food: "Chao yen mach", calories: 500)

        let hero = app.staticTexts["hero.remaining"]
        XCTAssertTrue(hero.waitForExistence(timeout: 30))
        XCTAssertEqual(hero.label, "\(vn(1878)) kcal còn lại")
        XCTAssertTrue(app.buttons["mealRow.breakfast"].label.contains("500"))
    }

    func testCrossingSeventyPercentShowsTheInformMessage() {
        reachDashboard()

        // 70% of 2378 is 1664.6, so 1700 kcal crosses it.
        logMeal(named: "lunch", food: "Com trua", calories: 1700)

        XCTAssertTrue(
            app.staticTexts["Bạn còn \(vn(678)) kcal cho hôm nay."]
                .waitForExistence(timeout: 30)
        )
    }

    func testExceedingTheTargetIsReportedNeutrally() {
        reachDashboard()

        logMeal(named: "dinner", food: "Tiec toi", calories: 2500)

        // Over budget reads as a fact, never a reprimand (handoff §4).
        XCTAssertTrue(
            app.staticTexts["Bạn đã vượt mục tiêu hôm nay \(vn(122)) kcal."]
                .waitForExistence(timeout: 30)
        )
        XCTAssertEqual(app.staticTexts["hero.remaining"].label, "\(vn(122)) kcal vượt mục tiêu")
    }

    // MARK: Helpers

    /// The app formats every number as `vi_VN` ("1.878") whatever the device
    /// locale is, so expectations are built the same way.
    private func vn(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func reachDashboard() {
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 30))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["mealRow.breakfast"].waitForExistence(timeout: 30))
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
}
