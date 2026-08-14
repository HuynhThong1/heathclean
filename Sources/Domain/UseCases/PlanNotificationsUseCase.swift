import Foundation

extension CalorieBudgetStatus {
    /// Which switch governs an alert about this status, or `nil` when there is
    /// nothing to say. Mirrors `EvaluateCalorieBudgetUseCase.message`, which is
    /// also silent below 70%.
    public var notificationPreference: NotificationPreference? {
        switch self {
        case .normal: nil
        case .informUser: .seventyPercent
        case .nearTarget: .nearTarget
        case .reached, .exceeded: .targetReached
        }
    }
}

/// Decides which notifications a day justifies (§19).
///
/// Pure, and deliberately so: the whole of the rule set is here, where it can be
/// tested without a simulator or a permission dialog, and the App layer is left
/// with `UNUserNotificationCenter` plumbing and the Vietnamese copy.
public struct PlanNotificationsUseCase: Sendable {
    private let calendar: Calendar
    private let reminderHour: Int
    private let summaryHour: Int

    /// The two hours are **this app's choice, not the spec's** — §19 asks for a
    /// reminder and a summary and names no time. Evening, and an hour apart so
    /// that a user with both switches on never gets two notifications in the
    /// same minute.
    public init(calendar: Calendar, reminderHour: Int = 20, summaryHour: Int = 21) {
        self.calendar = calendar
        self.reminderHour = reminderHour
        self.summaryHour = summaryHour
    }

    /// The alert a change in the day's budget justifies, if any.
    ///
    /// `alreadyNotified` is the highest rung reached *today*, so climbing from
    /// 70% to 90% notifies once at each and re-opening the app in between
    /// notifies not at all. Passing `nil` is a fresh day.
    ///
    /// A switch that is off suppresses its own rung and no other: turning
    /// "70%" off and leaving "90%" on means the first thing the user hears about
    /// is 90%, which is what the switch says.
    public func budgetAlert(
        current: CalorieBudgetStatus,
        alreadyNotified: CalorieBudgetStatus?,
        preferences: NotificationPreferences
    ) -> PlannedNotification? {
        guard let preference = current.notificationPreference else { return nil }
        guard current > (alreadyNotified ?? .normal) else { return nil }
        guard preferences.isOn(preference) else { return nil }
        return PlannedNotification(kind: .budget(current), fireDate: nil)
    }

    /// What to have waiting for the rest of today.
    ///
    /// **The reminder and the summary are mutually exclusive**, decided by
    /// whether anything has been logged: a day with no meals has nothing to
    /// summarise, and a day with meals does not need reminding. That also means
    /// a user with both switches on gets exactly one evening notification.
    ///
    /// Only *today* is planned, never tomorrow. The summary carries the day's
    /// real figures, which are not knowable in advance, and the reminder would
    /// have to fire on a day the app never saw — so both are re-planned every
    /// time the app learns something, and a day the app is never opened on
    /// produces nothing. A notification that would have to invent its own
    /// contents is the "switch that schedules nothing" mistake with a payload.
    public func dailySchedule(
        preferences: NotificationPreferences,
        hasLoggedToday: Bool,
        now: Date
    ) -> [PlannedNotification] {
        let preference: NotificationPreference = hasLoggedToday ? .dailySummary : .mealReminder
        guard preferences.isOn(preference) else { return [] }

        // Built from `now`'s own components rather than with
        // `date(bySettingHour:of:matchingPolicy:direction:)`, which searches
        // *forward*: past the hour it would hand back tomorrow, and tomorrow is
        // exactly the day this must not plan for.
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hasLoggedToday ? summaryHour : reminderHour
        guard let fireDate = calendar.date(from: components), fireDate > now else { return [] }

        return [
            PlannedNotification(
                kind: hasLoggedToday ? .dailySummary : .mealReminder,
                fireDate: fireDate
            )
        ]
    }
}
