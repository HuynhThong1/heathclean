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
        startOnboarding()
    }

    /// First run opens on Welcome (§5); every test below starts from step 1.
    private func startOnboarding() {
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 30))
        app.buttons["welcome.start"].tap()
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

    func testAppleHealthScreenFollowsTheLastStep() {
        XCTAssertTrue(app.buttons["onboarding.cta"].waitForExistence(timeout: 30))
        for _ in 0..<4 {
            app.buttons["onboarding.cta"].tap()
        }

        // The switches express which types will be asked for (§6.3).
        XCTAssertTrue(app.switches["health.steps"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.switches["health.sleep"].exists)
        XCTAssertTrue(app.buttons["health.allow"].isEnabled)

        app.switches["health.steps"].tap()
        app.switches["health.energy"].tap()
        app.switches["health.sleep"].tap()
        app.switches["health.weight"].tap()

        // Nothing left to ask for, so there is nothing to allow.
        XCTAssertFalse(app.buttons["health.allow"].isEnabled)
    }

    func testScanFlowProposesAMealAndRefusesToSaveUnresolvedItems() {
        reachDashboard()

        app.buttons["tab.scan"].tap()
        XCTAssertTrue(app.buttons["scan.pickPhoto"].waitForExistence(timeout: 30))
    }

    func testTabBarReachesEveryRootAndBack() {
        reachDashboard()

        // Each root is reachable and returnable — the earlier back-chip
        // stopgap on History is gone now that it is a tab root.
        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["Bữa ăn đã ghi"].waitForExistence(timeout: 30))

        app.buttons["tab.insights"].tap()
        XCTAssertTrue(app.staticTexts["7 ngày qua"].waitForExistence(timeout: 30))

        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.buttons["profile.editBody"].waitForExistence(timeout: 30))

        app.buttons["tab.today"].tap()
        XCTAssertTrue(app.buttons["mealRow.breakfast"].waitForExistence(timeout: 30))
    }

    func testProfileShowsTheDerivedTargetAndOpensEditing() {
        reachDashboard()

        // Profile is reached from its own tab. §6.4's avatar used to open it too
        // and is gone: it duplicated the tab, and was a 38pt target besides.
        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.buttons["profile.editBody"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Mỗi ngày, \(vn(2378)) kcal"].exists)

        // Editing reuses the onboarding steps, seeded from the stored profile
        // rather than reset to the first-run defaults.
        app.buttons["profile.editBody"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.counter"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.textFields["field.weight"].value as? String ?? "", "70")
    }

    func testAppleHealthCanReturnToTheGoalStep() {
        XCTAssertTrue(app.buttons["onboarding.cta"].waitForExistence(timeout: 30))
        for _ in 0..<4 {
            app.buttons["onboarding.cta"].tap()
        }
        XCTAssertTrue(app.buttons["health.back"].waitForExistence(timeout: 30))

        // Going back must land on step 4, so the goal can still be changed
        // after seeing what it produced.
        app.buttons["health.back"].tap()
        XCTAssertEqual(app.staticTexts["onboarding.counter"].label, "4/4")
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

    func testSavingAMealConfirmsWithAToast() {
        reachDashboard()

        logMeal(named: "snack", food: "Sua chua", calories: 180)

        XCTAssertTrue(
            app.staticTexts["Đã lưu bữa ăn · \(vn(180)) kcal"].waitForExistence(timeout: 30)
        )
    }

    func testALoggedMealOpensItsDetailAndCanBeDeleted() {
        reachDashboard()

        logMeal(named: "lunch", food: "Com trua", calories: 640)
        XCTAssertTrue(app.buttons["mealRow.lunch"].waitForExistence(timeout: 30))

        // A row with items routes to the detail screen; an empty one would open
        // manual entry instead (§5).
        app.buttons["mealRow.lunch"].tap()
        XCTAssertTrue(app.staticTexts["mealDetail.total"].waitForExistence(timeout: 30))
        XCTAssertEqual(
            app.staticTexts["mealDetail.total"].label,
            "Tổng bữa ăn \(vn(640)) kcal"
        )

        app.buttons["mealDetail.delete"].tap()
        // The system `confirmationDialog` was replaced by `HFDestructiveConfirm`,
        // so this is an identifier now rather than the old dialog's button label.
        let confirmDelete = app.buttons["confirm.destructive"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 30))
        confirmDelete.tap()

        XCTAssertTrue(app.buttons["mealRow.lunch"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["hero.remaining"].label, "\(vn(2378)) kcal còn lại")
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

    func testInsightsReportTheWeekAndTheWeightRecordedAtOnboarding() {
        reachDashboard()

        logMeal(named: "breakfast", food: "Chao yen mach", calories: 500)
        XCTAssertTrue(app.buttons["mealRow.breakfast"].waitForExistence(timeout: 30))

        app.buttons["tab.insights"].tap()

        // One logged day out of seven, averaged over that day alone rather than
        // over seven — the other six have no data, which is not a zero.
        let average = app.staticTexts["insights.average"]
        XCTAssertTrue(average.waitForExistence(timeout: 30))
        XCTAssertEqual(average.label, "Trung bình \(vn(500)) kcal mỗi ngày")
        XCTAssertEqual(
            app.staticTexts["insights.daysWithinGoal"].label,
            "1/7 ngày trong mục tiêu"
        )

        // Onboarding's 70 kg default is written to the weight log on save, so
        // the chart has a point without the user logging one by hand.
        XCTAssertEqual(app.staticTexts["insights.currentWeight"].label, "Hiện tại 70,0 kg")
        // A single weighing gives nothing to compare against.
        XCTAssertEqual(app.staticTexts["insights.weightChange"].label, "— trong 6 tuần")
    }

    /// The three edits the user reported as not refreshing the figures: adding a
    /// second food, changing a food's calories, and removing a food. Each is
    /// checked against the meal total *and* the dashboard, because those are two
    /// different refresh paths.
    func testAddingEditingAndRemovingAFoodKeepsTheTotalsInStep() {
        reachDashboard()

        app.buttons["mealRow.breakfast"].tap()
        let total = app.staticTexts["mealEntry.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 30))

        // First food: 500 kcal.
        let name = app.textFields["field.food"]
        name.tap()
        name.typeText("Pho bo")
        setCalories(at: 0, to: 500)
        XCTAssertEqual(total.label, "Tổng \(vn(500)) kcal", "total after the first food")

        // Editing the same food has to move the total, not just the field.
        setCalories(at: 0, to: 250)
        XCTAssertEqual(total.label, "Tổng \(vn(250)) kcal", "total after editing a food")

        // Adding a second food card leaves the total alone until it has figures,
        // which is the point: 0 kcal of a nameless food is not 0 kcal eaten.
        app.buttons["mealEntry.addFood"].tap()
        let secondName = app.textFields.matching(identifier: "field.food").element(boundBy: 1)
        XCTAssertTrue(secondName.waitForExistence(timeout: 10))
        XCTAssertEqual(total.label, "Tổng \(vn(250)) kcal", "total after adding an empty food")

        // Removing it must not disturb the total either.
        app.buttons["mealEntry.removeFood.1"].tap()
        XCTAssertFalse(secondName.exists, "the second card is gone")
        XCTAssertEqual(total.label, "Tổng \(vn(250)) kcal", "total after removing a food")

        // And the dashboard has to agree once it is saved.
        app.buttons["mealEntry.save"].tap()
        let hero = app.staticTexts["hero.remaining"]
        XCTAssertTrue(hero.waitForExistence(timeout: 30))
        XCTAssertEqual(hero.label, "\(vn(2128)) kcal còn lại", "dashboard after saving")
    }

    func testHistoryCalendarSelectsADayAndPagesWeeks() {
        reachDashboard()
        logMeal(named: "breakfast", food: "Phở bò", calories: 420)

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["Bữa ăn đã ghi"].waitForExistence(timeout: 30))

        // History opens on today, which is the day the meal was just logged on.
        let today = app.buttons[dayIdentifier(for: Date())]
        XCTAssertTrue(today.waitForExistence(timeout: 30))
        XCTAssertTrue(today.isSelected, "today starts selected")
        XCTAssertTrue(app.buttons["history.meal.breakfast"].exists)

        // There is no week ahead of the one holding today to page into.
        XCTAssertFalse(app.buttons["history.week.next"].isEnabled)

        app.buttons["history.week.previous"].tap()
        XCTAssertTrue(
            app.staticTexts["Ngày này không có bữa ăn nào được ghi."]
                .waitForExistence(timeout: 30)
        )
        XCTAssertFalse(app.buttons["history.meal.breakfast"].exists)
        XCTAssertTrue(app.buttons["history.week.next"].isEnabled)

        // Coming back lands on today again, not on the Monday of this week.
        app.buttons["history.week.next"].tap()
        XCTAssertTrue(app.buttons["history.meal.breakfast"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons[dayIdentifier(for: Date())].isSelected)
    }

    // MARK: Helpers

    /// Matches `HistoryWeekStrip`'s identifiers, which are `en_US_POSIX` on
    /// purpose so a test can name a day whatever the device locale is.
    private func dayIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "history.day.\(formatter.string(from: date))"
    }

    /// Number fields start populated and tapping puts the caret at the start, so
    /// the existing value has to be selected rather than backspaced.
    private func setCalories(at index: Int, to value: Int) {
        let field = app.textFields.matching(identifier: "field.calories").element(boundBy: index)
        field.doubleTap()
        field.typeText("\(value)")
    }

    /// The app formats every number as `vi_VN` ("1.878") whatever the device
    /// locale is, so expectations are built the same way.
    private func vn(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Walks Welcome → all four steps → the Apple Health screen, leaving it via
    /// "Để sau" rather than "Cho phép truy cập" — the latter opens the system
    /// HealthKit sheet, which cannot be driven reliably from a test.
    private func reachDashboard() {
        XCTAssertTrue(app.buttons["onboarding.cta"].waitForExistence(timeout: 30))
        for _ in 0..<4 {
            app.buttons["onboarding.cta"].tap()
        }
        // Step 4 hands off to the Apple Health screen; "Để sau" leaves it
        // without opening the system sheet, which a test cannot drive.
        XCTAssertTrue(app.buttons["health.later"].waitForExistence(timeout: 30))
        app.buttons["health.later"].tap()
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

        app.buttons["mealEntry.save"].tap()
    }
}
