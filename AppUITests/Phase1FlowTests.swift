import XCTest

/// Walks the flow the way a user would: four onboarding steps produce a target,
/// a logged meal moves the dashboard, and crossing a threshold surfaces the
/// status note.
///
/// Both screens now follow the design handoff and are Vietnamese-primary.
/// Numbers are built with a `vi_VN` formatter rather than hardcoded, because
/// the app formats with that locale whatever the device is set to.
final class Phase1FlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testOnboardingWalksFourStepsAndProducesTargets() {
        XCTAssertTrue(app.staticTexts["onboarding.counter"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["onboarding.counter"].label, "1/4")

        // Defaults: 170 cm, 70 kg, 30 y, unspecified sex, moderate, maintain
        // → BMR 1534.5 × 1.55 = 2378 kcal, protein 70 × 1.6 = 112 g.
        app.buttons["onboarding.cta"].tap()
        XCTAssertEqual(app.staticTexts["onboarding.counter"].label, "2/4")

        app.buttons["onboarding.cta"].tap()
        XCTAssertEqual(app.staticTexts["onboarding.counter"].label, "3/4")

        app.buttons["onboarding.cta"].tap()
        XCTAssertEqual(app.staticTexts["onboarding.counter"].label, "4/4")

        XCTAssertEqual(
            app.staticTexts["result.calories"].label,
            "\(vn(2378)) kcal mỗi ngày"
        )
        XCTAssertTrue(app.staticTexts["Đạm, \(vn(112)) gam"].exists)
    }

    func testGoingBackReturnsToTheEarlierStep() {
        XCTAssertTrue(app.buttons["onboarding.cta"].waitForExistence(timeout: 30))
        app.buttons["onboarding.cta"].tap()
        XCTAssertEqual(app.staticTexts["onboarding.counter"].label, "2/4")

        app.buttons["onboarding.back"].tap()
        XCTAssertEqual(app.staticTexts["onboarding.counter"].label, "1/4")
    }

    func testOutOfRangeWeightBlocksTheStepAndSaysWhy() {
        XCTAssertTrue(app.textFields["field.weight"].waitForExistence(timeout: 30))

        let weight = app.textFields["field.weight"]
        weight.doubleTap()
        weight.typeText("500")
        // `TextField(value:format:)` commits on end-editing, so move focus off.
        app.staticTexts["Tuổi, Age"].tap()

        // DSFieldMessage prefixes its accessibility label with "Error: " so
        // VoiceOver distinguishes an error from a hint.
        XCTAssertTrue(
            app.staticTexts["Error: Nhập cân nặng từ 25 đến 400 kg"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.buttons["onboarding.cta"].isEnabled)
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

    /// Walks all four steps with the defaults. The final step is left via
    /// "Để sau" rather than the primary CTA — the CTA opens the system
    /// HealthKit sheet, which cannot be driven reliably from a test.
    private func reachDashboard() {
        XCTAssertTrue(app.buttons["onboarding.cta"].waitForExistence(timeout: 30))
        for _ in 0..<3 {
            app.buttons["onboarding.cta"].tap()
        }
        app.buttons["onboarding.skipHealth"].tap()
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
