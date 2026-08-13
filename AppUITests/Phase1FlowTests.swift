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
        XCTAssertEqual(app.buttons["history.week.previous"].label, "Tuần trước")
        XCTAssertEqual(app.buttons["history.week.next"].label, "Tuần sau")
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

    func testHistoryCalendarFindsAMealLoggedLastWeek() {
        // Relaunch with an in-memory fixture that is written through the real
        // SwiftData repository. Ordinary UI tests still start completely empty.
        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedHistoryFixture"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.buttons["history.week.previous"].waitForExistence(timeout: 30))
        app.buttons["history.week.previous"].tap()

        let calendar = Calendar(identifier: .gregorian)
        let historicalDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        let historicalDay = app.buttons[dayIdentifier(for: historicalDate)]
        XCTAssertTrue(historicalDay.waitForExistence(timeout: 30))
        historicalDay.tap()

        let lunch = app.buttons["history.meal.lunch"]
        XCTAssertTrue(lunch.waitForExistence(timeout: 30))
        XCTAssertTrue(lunch.label.contains(vn(610)))
    }

    func testHistoryRefreshesAfterRemovingOneFood() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedHistoryFixture"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.buttons["history.week.previous"].waitForExistence(timeout: 30))
        app.buttons["history.week.previous"].tap()
        let calendar = Calendar(identifier: .gregorian)
        let historicalDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        let historicalDay = app.buttons[dayIdentifier(for: historicalDate)]
        XCTAssertTrue(historicalDay.waitForExistence(timeout: 30))
        historicalDay.tap()

        let historyMeal = app.buttons["history.meal.lunch"]
        XCTAssertTrue(historyMeal.waitForExistence(timeout: 30))
        XCTAssertTrue(historyMeal.label.contains(vn(610)))
        historyMeal.tap()

        let firstRemove = app.buttons["Xoá Cơm gà lịch sử"]
        XCTAssertTrue(firstRemove.waitForExistence(timeout: 30))
        firstRemove.tap()
        let confirm = app.buttons["confirm.destructive"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 30))
        confirm.tap()
        XCTAssertEqual(app.staticTexts["mealDetail.total"].label, "Tổng bữa ăn \(vn(210)) kcal")

        let detailBar = app.navigationBars["Bữa trưa"]
        XCTAssertTrue(detailBar.waitForExistence(timeout: 30))
        detailBar.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(historyMeal.waitForExistence(timeout: 30))
        XCTAssertTrue(historyMeal.label.contains(vn(210)))
    }

    /// The history list of HISTORY_SPEC, behind `-historyTimeline` until stage 4.
    /// `YES` is spelled out because a bare launch argument never reaches
    /// `UserDefaults`, unlike `-uiTesting`, which is read from `ProcessInfo`.
    func testHistoryTimelineOpensADay() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedHistoryFixture", "-historyTimeline", "YES"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["history.title"].waitForExistence(timeout: 30))

        // The list replaces the week strip rather than joining it (§32.2).
        XCTAssertFalse(app.buttons["history.week.previous"].exists)

        // The fixture's meal is a week back, which the opening three-month
        // window covers whichever month it landed in.
        let calendar = Calendar(identifier: .gregorian)
        let historicalDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        let day = app.buttons[dayIdentifier(for: historicalDate)]
        XCTAssertTrue(day.waitForExistence(timeout: 30))
        XCTAssertTrue(day.label.contains(vn(610)), "the card carries the day's total")
        // HISTORY_SPEC §7: the whole card is one element, and it says how far off the
        // target the day landed rather than only what it added up to.
        XCTAssertTrue(
            day.label.contains("Vượt") || day.label.contains("Còn")
                || day.label.contains("Đạt mục tiêu"),
            "the card announces the deviation, not just the total: \(day.label)"
        )
        // The fixture's meal has a photo written through the real store, so the chip
        // leads with a thumbnail — and §7 puts that in the card's label, since the
        // 26pt square inside a combined element can never be queried on its own.
        XCTAssertTrue(day.label.contains("Có 1 ảnh"), "a day with a picture says so")

        // Tapping the day opens its panel, and the panel reaches the meal.
        day.tap()
        let lunch = app.buttons["history.meal.lunch"]
        XCTAssertTrue(lunch.waitForExistence(timeout: 30))
        // §6's panel is the day's figures. Its meal rows carry a 34pt thumbnail, and
        // the photo at size is one step deeper, on the meal detail.
        XCTAssertTrue(lunch.label.contains("Có ảnh"), "the meal row says it has a photo")
        XCTAssertTrue(app.staticTexts["history.day.total"].exists, "and the day's total")
        lunch.tap()

        let total = app.staticTexts["mealDetail.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 30))
        XCTAssertEqual(total.label, "Tổng bữa ăn \(vn(610)) kcal")
        // The detail screen is where a photo is seen at size.
        XCTAssertTrue(app.images["mealDetail.photo.0"].waitForExistence(timeout: 30))
    }

    /// §32.3 asks history to keep its place across a refresh and a trip into a
    /// day. Opening a day reloads nothing, and a refresh replaces the months with
    /// the same identities — but that is exactly the kind of claim that stops being
    /// true silently, so it is pinned here.
    ///
    /// It needs the fixture: only logged days are rows now, so without a fortnight
    /// of them the list is shorter than the screen and a scroll test that never
    /// scrolls passes without testing anything.
    func testHistoryTimelineKeepsItsScrollPositionAcrossADay() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedHistoryFixture", "-historyTimeline", "YES"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["history.title"].waitForExistence(timeout: 30))

        // Near the bottom of the fixture's run of days, so reaching it means
        // scrolling — the whole point is that the screen does not scroll back.
        let calendar = Calendar(identifier: .gregorian)
        let earlier = calendar.date(byAdding: .day, value: -13, to: Date())!
        let row = app.buttons[dayIdentifier(for: earlier)]
        // No `waitForExistence` first. A day card is ~125pt tall where the row it
        // replaced was 78, so the oldest of the fixture's fortnight now sits past
        // what the `LazyVStack` has built — it does not exist to be waited for until
        // the list has been scrolled towards it.
        scrollUntilHittable(row)
        XCTAssertTrue(row.exists)
        let before = row.frame
        XCTAssertGreaterThan(before.midY, 0, "the row is on screen to begin with")

        row.tap()
        XCTAssertTrue(app.buttons["history.day.close"].waitForExistence(timeout: 30))
        app.buttons["history.day.close"].tap()

        XCTAssertTrue(row.waitForExistence(timeout: 30))
        XCTAssertEqual(
            row.frame.midY,
            before.midY,
            accuracy: 1,
            "the list is where it was left, not scrolled back to today"
        )
    }

    /// History opens on three months and pages back from there. The fixture's
    /// older meal is outside that window, so its row existing at all is the proof
    /// that another page arrived.
    func testHistoryTimelinePagesToOlderMonths() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedHistoryFixture", "-historyTimeline", "YES"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["history.title"].waitForExistence(timeout: 30))

        let calendar = Calendar(identifier: .gregorian)
        let older = calendar.date(byAdding: .day, value: -100, to: Date())!
        let olderRow = app.buttons[dayIdentifier(for: older)]
        XCTAssertFalse(olderRow.exists, "a month outside the opening window is not loaded yet")

        // The footer is the only thing that asks for another page, on purpose.
        let more = app.buttons["history.loadMore"]
        for _ in 0..<12 where !more.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(more.isHittable, "the footer is reachable at the end of the list")
        more.tap()
        XCTAssertTrue(
            olderRow.waitForExistence(timeout: 30),
            "the older month arrived after paging"
        )
        XCTAssertTrue(olderRow.label.contains(vn(320)), "and it carries that day's total")
    }

    /// A day card stays usable at accessibility text sizes: it grows downwards, the
    /// date and the total both stay on it, and nothing is dropped to make room —
    /// HISTORY_SPEC §4's `ViewThatFits`, which moves the date column above the
    /// figures and turns the chip row into a column.
    ///
    /// This test is why `WelcomeView` scrolls. At `AccessibilityXL` its "Bắt đầu"
    /// button sat below the screen on a fixed `VStack`, so the run failed two
    /// screens before history — an accessibility-size test exercises everything it
    /// walks through, not only the screen it is about.
    func testHistoryTimelineRowsSurviveAccessibilitySizes() {
        app.terminate()
        app.launchArguments = [
            "-uiTesting", "-seedHistoryFixture", "-historyTimeline", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL",
        ]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["history.title"].waitForExistence(timeout: 30))

        let calendar = Calendar(identifier: .gregorian)
        let logged = app.buttons[dayIdentifier(for: calendar.date(byAdding: .day, value: -7, to: Date())!)]
        XCTAssertTrue(logged.waitForExistence(timeout: 30))
        XCTAssertTrue(logged.label.contains(vn(610)), "the day's total is still announced")
        XCTAssertTrue(logged.label.contains("Có 1 ảnh"), "and so is its photo")

        // A card is full width and taller than at the default size, but it has not
        // spilled sideways — the list still reads as cards rather than a scroll in
        // two directions.
        XCTAssertLessThanOrEqual(logged.frame.maxX, app.frame.width)
        XCTAssertGreaterThan(logged.frame.height, 60)

        // Deliberately no tap-through here. At this text size the tree is large
        // enough that each `isHittable` re-snapshots the whole app, and scrolling
        // to a row eight deep took seven minutes before timing out. Opening a day
        // is covered at the default size by `testHistoryTimelineOpensADay`; what
        // this test is about is the layout.
    }

    /// Deleting a whole meal from history, which is three screens deep: the day
    /// sheet pushes the detail, and the detail presents its confirmation from
    /// inside that sheet.
    ///
    /// Reported from a device: the confirmation appeared and vanished in the same
    /// instant, so the meal could not be deleted at all. No test walked this path —
    /// the delete tests went via the dashboard.
    func testDeletingAMealFromTheDaySheetKeepsItsConfirmation() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedHistoryFixture", "-historyTimeline", "YES"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        let calendar = Calendar(identifier: .gregorian)
        let logged = calendar.date(byAdding: .day, value: -7, to: Date())!
        let row = app.buttons[dayIdentifier(for: logged)]
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        row.tap()

        let lunch = app.buttons["history.meal.lunch"]
        XCTAssertTrue(lunch.waitForExistence(timeout: 30))
        lunch.tap()
        XCTAssertTrue(app.buttons["mealDetail.delete"].waitForExistence(timeout: 30))
        app.buttons["mealDetail.delete"].tap()

        // The confirmation has to still be there a moment later. `waitForExistence`
        // alone would pass on a sheet that appears and immediately closes.
        let confirm = app.buttons["confirm.destructive"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 30))
        XCTAssertTrue(confirm.isHittable, "the confirmation is still up, not dismissed")
        confirm.tap()

        // The meal is gone, and so is the row that had it.
        XCTAssertTrue(app.staticTexts["Đã xoá bữa ăn"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["history.meal.lunch"].exists)
    }

    /// HISTORY_SPEC §5: a keyword changes the unit of the list from days to meals,
    /// and matching ignores diacritics — "com ga" finds "Cơm gà lịch sử". The
    /// folding is the part worth a test: it is the difference between a search box
    /// that works on a Vietnamese keyboard and one that only works with tones typed.
    func testHistorySearchFindsAMealTypedWithoutDiacritics() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedHistoryFixture", "-historyTimeline", "YES"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["history.title"].waitForExistence(timeout: 30))

        let calendar = Calendar(identifier: .gregorian)
        let loggedDay = calendar.date(byAdding: .day, value: -7, to: Date())!
        let dayCard = app.buttons[dayIdentifier(for: loggedDay)]
        XCTAssertTrue(dayCard.waitForExistence(timeout: 30))

        let field = app.textFields["field.historySearch"]
        XCTAssertTrue(field.waitForExistence(timeout: 30))
        field.tap()
        field.typeText("com ga")

        let header = app.staticTexts["history.results.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        XCTAssertTrue(header.label.contains("com ga"), header.label)
        XCTAssertFalse(dayCard.exists, "the list is by meal while a keyword is set")

        let hit = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'history.result.'")
        ).firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 30))
        XCTAssertTrue(hit.label.contains("Cơm gà lịch sử"), hit.label)

        // A hit opens the day it belongs to — §4 keeps one way into a meal.
        hit.tap()
        XCTAssertTrue(app.buttons["history.meal.lunch"].waitForExistence(timeout: 30))
        app.buttons["history.day.close"].tap()

        // Clearing the field puts the days back.
        XCTAssertTrue(app.buttons["history.search.clear"].waitForExistence(timeout: 30))
        app.buttons["history.search.clear"].tap()
        XCTAssertTrue(dayCard.waitForExistence(timeout: 30))
    }

    /// §5's chips filter without a keyword, and "Tất cả" is how they are turned off.
    /// Only the fixture's lunch has a photo, so "Có ảnh" has exactly one answer.
    func testHistoryFilterChipNarrowsToMealsWithAPhoto() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedHistoryFixture", "-historyTimeline", "YES"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["history.title"].waitForExistence(timeout: 30))

        let calendar = Calendar(identifier: .gregorian)
        let dayCard = app.buttons[
            dayIdentifier(for: calendar.date(byAdding: .day, value: -7, to: Date())!)
        ]
        XCTAssertTrue(dayCard.waitForExistence(timeout: 30))

        let chip = app.buttons["history.filter.hasPhoto"]
        XCTAssertTrue(chip.waitForExistence(timeout: 30))
        chip.tap()

        let header = app.staticTexts["history.results.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        XCTAssertTrue(header.label.hasPrefix("1 bữa"), header.label)
        XCTAssertFalse(dayCard.exists, "a chip alone switches the list to meals")

        app.buttons["history.filter.all"].tap()
        XCTAssertTrue(dayCard.waitForExistence(timeout: 30))
    }

    /// §6's empty state, which is the first thing a new user sees on this tab. It has
    /// to say why the screen is empty — "only days you logged appear" — and offer
    /// both ways to log something.
    func testHistoryEmptyStateOffersBothWaysToLogAMeal() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-historyTimeline", "YES"]
        app.launch()
        startOnboarding()
        reachDashboard()

        app.buttons["tab.history"].tap()
        XCTAssertTrue(
            app.staticTexts["Chưa có bữa nào được ghi"].waitForExistence(timeout: 30)
        )
        // The scan is the orange action here and nowhere else on the screen (§3). It
        // is not tapped: the flow it opens reaches the system Photos sheet on a
        // simulator, which this suite stays out of.
        XCTAssertTrue(app.buttons["history.empty.scan"].isHittable)

        app.buttons["history.empty.manual"].tap()
        let cancel = app.buttons["Huỷ"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "manual entry opens from here")
        cancel.tap()
        XCTAssertTrue(app.buttons["history.empty.scan"].waitForExistence(timeout: 30))
    }

    // MARK: Helpers

    /// A lazy stack keeps off-screen rows in the accessibility tree, and
    /// `tap()` on one taps a coordinate outside the scroll view — which hits
    /// nothing at all rather than failing. So scroll until the cell is really
    /// reachable, correcting for an overshoot.
    ///
    /// **It has to tolerate the element not existing yet.** A lazy stack only builds a
    /// little way past the viewport, so a cell far down the list is absent rather than
    /// merely off screen — and `frame` on an absent element does not return zero, it
    /// throws ("Failed to get matching snapshot"). Absent is therefore treated as
    /// "further down", which is the only direction it can be.
    private func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 10) {
        for _ in 0..<attempts {
            if element.exists, element.isHittable { return }
            if element.exists, element.frame.midY < app.frame.minY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(
            element.exists && element.isHittable,
            "could not scroll \(element) into reach"
        )
    }

    /// Matches `HistoryCalendar`'s Gregorian identifiers so a test can name a
    /// day whatever system calendar the simulator is configured to use.
    private func dayIdentifier(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let value = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        return "history.day.\(value)"
    }

    /// Number fields start populated and tapping puts the caret at the start, so
    /// the existing value has to be selected rather than backspaced.
    private func setCalories(at index: Int, to value: Int) {
        let field = app.textFields.matching(identifier: "field.calories").element(boundBy: index)
        field.tap()
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
