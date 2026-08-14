import Domain
import Foundation
import Testing

@Suite("Notification planning")
struct PlanNotificationsTests {
    private let planner = PlanNotificationsUseCase(calendar: testCalendar)
    private let all = NotificationPreferences(enabled: Set(NotificationPreference.allCases))

    /// A fixed instant on the same UTC day as `referenceDate` (2023-11-14).
    private func today(atHour hour: Int, minute: Int = 0) -> Date {
        var components = testCalendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hour
        components.minute = minute
        return testCalendar.date(from: components)!
    }

    // MARK: Budget alerts

    @Test("nothing is said below the first threshold")
    func silentBelowSeventy() {
        let alert = planner.budgetAlert(
            current: .normal, alreadyNotified: nil, preferences: all
        )
        #expect(alert == nil)
    }

    @Test(
        "each rung of the ladder notifies once",
        arguments: [
            CalorieBudgetStatus.informUser,
            .nearTarget,
            .reached,
            .exceeded,
        ]
    )
    func eachRungNotifiesOnce(status: CalorieBudgetStatus) {
        let first = planner.budgetAlert(
            current: status, alreadyNotified: nil, preferences: all
        )
        #expect(first?.kind == .budget(status))

        // Re-opening the app, or logging a meal that does not move the day up a
        // rung, must not say the same thing twice.
        let again = planner.budgetAlert(
            current: status, alreadyNotified: status, preferences: all
        )
        #expect(again == nil)
    }

    @Test("climbing past a rung already announced still notifies")
    func climbingNotifiesAgain() {
        let alert = planner.budgetAlert(
            current: .nearTarget, alreadyNotified: .informUser, preferences: all
        )
        #expect(alert?.kind == .budget(.nearTarget))
    }

    /// Deleting a food drops the day back down; that is not an event.
    @Test("falling back down says nothing")
    func fallingBackIsSilent() {
        let alert = planner.budgetAlert(
            current: .informUser, alreadyNotified: .exceeded, preferences: all
        )
        #expect(alert == nil)
    }

    @Test("passing the target is the same switch as reaching it")
    func exceededFollowsTheReachedSwitch() {
        var preferences = all
        preferences.set(.targetReached, on: false)

        #expect(
            planner.budgetAlert(
                current: .exceeded, alreadyNotified: nil, preferences: preferences
            ) == nil
        )
    }

    /// A switch that is off silences its own rung and no other — otherwise
    /// turning "70%" off would silently disable the two above it.
    @Test("a switch that is off does not silence the rungs above it")
    func offSwitchDoesNotSilenceHigherRungs() {
        var preferences = all
        preferences.set(.seventyPercent, on: false)

        #expect(
            planner.budgetAlert(
                current: .informUser, alreadyNotified: nil, preferences: preferences
            ) == nil
        )
        #expect(
            planner.budgetAlert(
                current: .nearTarget, alreadyNotified: nil, preferences: preferences
            )?.kind == .budget(.nearTarget)
        )
    }

    // MARK: The evening schedule

    @Test("a day with nothing logged gets the reminder, not the summary")
    func emptyDayGetsTheReminder() {
        let planned = planner.dailySchedule(
            preferences: all, hasLoggedToday: false, now: today(atHour: 9)
        )

        #expect(planned.count == 1)
        #expect(planned.first?.kind == .mealReminder)
        #expect(planned.first?.fireDate == today(atHour: 20))
    }

    @Test("a day with a meal gets the summary, not the reminder")
    func loggedDayGetsTheSummary() {
        let planned = planner.dailySchedule(
            preferences: all, hasLoggedToday: true, now: today(atHour: 9)
        )

        #expect(planned.count == 1)
        #expect(planned.first?.kind == .dailySummary)
        #expect(planned.first?.fireDate == today(atHour: 21))
    }

    @Test("the hour having passed leaves nothing to plan")
    func pastTheHourPlansNothing() {
        #expect(
            planner.dailySchedule(
                preferences: all, hasLoggedToday: false, now: today(atHour: 22)
            ).isEmpty
        )
        #expect(
            planner.dailySchedule(
                preferences: all, hasLoggedToday: true, now: today(atHour: 23, minute: 30)
            ).isEmpty
        )
    }

    /// Never tomorrow: the summary's figures are not knowable in advance and the
    /// reminder would have to fire on a day the app has not seen.
    @Test("only today is ever planned")
    func onlyTodayIsPlanned() throws {
        let now = today(atHour: 19, minute: 59)
        let planned = planner.dailySchedule(
            preferences: all, hasLoggedToday: false, now: now
        )

        let fired = try #require(planned.first?.fireDate)
        #expect(testCalendar.isDate(fired, inSameDayAs: now))
    }

    @Test("each evening notification answers to its own switch")
    func eveningSwitches() {
        var preferences = all
        preferences.set(.mealReminder, on: false)
        #expect(
            planner.dailySchedule(
                preferences: preferences, hasLoggedToday: false, now: today(atHour: 9)
            ).isEmpty
        )
        #expect(
            planner.dailySchedule(
                preferences: preferences, hasLoggedToday: true, now: today(atHour: 9)
            ).count == 1
        )

        preferences = all
        preferences.set(.dailySummary, on: false)
        #expect(
            planner.dailySchedule(
                preferences: preferences, hasLoggedToday: true, now: today(atHour: 9)
            ).isEmpty
        )
    }

    // MARK: Defaults

    @Test("the reminder is the one switch that starts off")
    func defaults() {
        let defaults = NotificationPreferences.default

        #expect(defaults.isOn(.seventyPercent))
        #expect(defaults.isOn(.nearTarget))
        #expect(defaults.isOn(.targetReached))
        #expect(defaults.isOn(.dailySummary))
        #expect(!defaults.isOn(.mealReminder))
    }
}
