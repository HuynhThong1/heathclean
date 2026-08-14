import Domain
import Foundation
import UserNotifications

/// Turns `PlanNotificationsUseCase`'s decisions into `UNUserNotificationCenter`
/// requests (plan.md §19).
///
/// **There is no `UNUserNotificationCenterDelegate`, deliberately.** Without one
/// iOS does not present a banner while the app is in the foreground, which is
/// exactly right here: every budget alert is caused by the user logging a meal,
/// and the dashboard is already showing them the same figure in a ring. The
/// notification is still *delivered*, so it is in Notification Center for a user
/// who put the phone down — see `budgetGrace` for how it gets a chance to be
/// seen as a banner.
@MainActor
@Observable
final class NotificationCoordinator {
    enum Authorization: Equatable {
        /// Never asked. The switches are inert until this changes.
        case notDetermined
        case granted
        /// Refused here or later turned off in Settings — only Settings can undo it.
        case denied
    }

    private(set) var authorization: Authorization = .notDetermined

    let settings: NotificationSettings

    private let userRepository: any UserRepository
    private let getDailySummary: GetDailySummaryUseCase
    private let evaluateCalorieBudget: EvaluateCalorieBudgetUseCase
    private let plan: PlanNotificationsUseCase
    /// The same calendar the planner and the history screen use, so a
    /// notification's idea of "today" cannot drift from the app's.
    private let calendar: Calendar
    private let defaults: UserDefaults
    private let isEnabled: Bool

    private enum Identifier {
        static let budget = "hf.budget"
        static let mealReminder = "hf.mealReminder"
        static let dailySummary = "hf.dailySummary"

        static let scheduled = [mealReminder, dailySummary]
    }

    private enum Key {
        static let lastStatus = "notification.lastBudgetStatus"
        static let lastStatusDay = "notification.lastBudgetStatusDay"
    }

    /// A budget alert fires this many seconds after the meal that caused it.
    ///
    /// Not zero, and not a rounder number for its own sake: with no delay the
    /// alert is always delivered while the app is in the foreground, where iOS
    /// suppresses the banner, so it could only ever be found later in
    /// Notification Center. Twenty seconds is long enough for a user who logged
    /// and left to see it on the lock screen, and short enough to still be about
    /// the meal they just logged. A user still on the dashboard sees nothing,
    /// which is the point.
    private static let budgetGrace: TimeInterval = 20

    /// UI tests must never meet a system permission dialog, and there is no way
    /// to dismiss one from XCUITest reliably — the same reason the suite avoids
    /// the HealthKit sheet. The switches still store their state under
    /// `-uiTesting`; only the scheduling is inert.
    init(
        userRepository: any UserRepository,
        getDailySummary: GetDailySummaryUseCase,
        evaluateCalorieBudget: EvaluateCalorieBudgetUseCase,
        plan: PlanNotificationsUseCase,
        calendar: Calendar,
        settings: NotificationSettings,
        defaults: UserDefaults = .standard,
        isEnabled: Bool = !ProcessInfo.processInfo.arguments.contains("-uiTesting")
    ) {
        self.userRepository = userRepository
        self.getDailySummary = getDailySummary
        self.evaluateCalorieBudget = evaluateCalorieBudget
        self.plan = plan
        self.calendar = calendar
        self.settings = settings
        self.defaults = defaults
        self.isEnabled = isEnabled

        // With the system out of reach the authorization would stay
        // `.notDetermined` for ever, which leaves the switches greyed out and
        // untestable. `-notificationsGranted` stands in for a granted permission
        // so a test can walk the state that actually has controls in it; nothing
        // is scheduled either way, because `isEnabled` gates that separately.
        if !isEnabled, ProcessInfo.processInfo.arguments.contains("-notificationsGranted") {
            authorization = .granted
        }
    }

    // MARK: Authorization

    /// Re-read from the system every time the app comes forward: the user can
    /// turn notifications off in Settings without the app running, and a screen
    /// still drawing live switches after that would be lying.
    func refreshAuthorization() async {
        guard isEnabled else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings()
            .authorizationStatus

        authorization = switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        // `.provisional` and `.ephemeral` may deliver quietly rather than not at
        // all, so they are granted as far as this app is concerned.
        default: .granted
        }
    }

    /// Asks once, from the button on Profile.
    ///
    /// Only `.alert` and `.sound`: nothing in the app sets a badge, and asking
    /// for a permission that is never used is the same mistake as a switch that
    /// schedules nothing.
    func requestAuthorization() async {
        guard isEnabled, authorization == .notDetermined else { return }
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        await refreshAuthorization()
        await refresh()
    }

    // MARK: Planning

    /// Re-reads today from the store and re-plans. For callers that do not
    /// already hold a summary — the tab shell on launch, on returning to the
    /// foreground, and after a scan saves from whichever tab the user was on.
    func refresh() async {
        guard isEnabled else { return }
        await refreshAuthorization()
        guard authorization == .granted else { return }
        guard let stored = try? await userRepository.load(),
              let summary = try? await getDailySummary.execute(date: Date(), goal: stored.goal)
        else { return }
        await apply(summary: summary)
    }

    /// The same work for a caller that just computed today — the dashboard,
    /// which reloads after every manual entry, every deletion and every profile
    /// edit, and would otherwise make the store answer the same question twice.
    func apply(summary: DailyNutritionSummary) async {
        guard isEnabled, authorization == .granted else { return }
        let center = UNUserNotificationCenter.current()
        let now = Date()
        let status = evaluateCalorieBudget.execute(budget: summary.budget)
        let alreadyNotified = recordedStatus(on: now)

        if let alert = plan.budgetAlert(
            current: status,
            alreadyNotified: alreadyNotified,
            preferences: settings.preferences
        ) {
            await add(alert, id: Identifier.budget, summary: summary, to: center)
        } else if status < (alreadyNotified ?? .normal) {
            // The day fell back — a food was removed within the grace window.
            // Take the alert back before it fires; leaving it would announce a
            // threshold the user has undone.
            center.removePendingNotificationRequests(withIdentifiers: [Identifier.budget])
        }
        // Recorded whether or not anything was delivered, so that turning a
        // switch on at 11pm does not fire the morning's threshold retroactively.
        record(status, on: now)

        let scheduled = plan.dailySchedule(
            preferences: settings.preferences,
            hasLoggedToday: !summary.meals.isEmpty,
            now: now
        )
        // The plan is authoritative: clear what the last one left before adding.
        // A day that starts empty and gets a meal at noon has to lose its
        // reminder, and the plan says so by not containing one.
        center.removePendingNotificationRequests(withIdentifiers: Identifier.scheduled)
        for item in scheduled {
            await add(item, id: identifier(for: item.kind), summary: summary, to: center)
        }
    }

    // MARK: Delivery

    private func add(
        _ planned: PlannedNotification,
        id: String,
        summary: DailyNutritionSummary,
        to center: UNUserNotificationCenter
    ) async {
        let copy = NotificationCopy.content(for: planned.kind, summary: summary)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

        let trigger: UNNotificationTrigger
        if let fireDate = planned.fireDate {
            // A *calendar* trigger for a wall-clock time, not the equivalent
            // interval: 20:00 has to stay 20:00 if the user flies somewhere, and
            // an interval computed now would keep the elapsed seconds instead.
            guard fireDate > Date() else { return }
            trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                ),
                repeats: false
            )
        } else {
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: Self.budgetGrace, repeats: false
            )
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        // A failed request is not worth failing anything over — the same rule as
        // a failed weight write not failing a profile save.
        try? await center.add(request)
    }

    private func identifier(for kind: PlannedNotification.Kind) -> String {
        switch kind {
        case .budget: Identifier.budget
        case .mealReminder: Identifier.mealReminder
        case .dailySummary: Identifier.dailySummary
        }
    }

    // MARK: The day's high-water mark

    /// The highest rung announced *today*, or `nil` on a new day. Stored beside
    /// the day it belongs to, because "already told them" has to expire at
    /// midnight and a bare status could not say when it was set.
    private func recordedStatus(on date: Date) -> CalorieBudgetStatus? {
        guard defaults.string(forKey: Key.lastStatusDay) == HistoryCalendar.identifier(for: date),
              let raw = defaults.string(forKey: Key.lastStatus)
        else { return nil }
        return CalorieBudgetStatus(rawValue: raw)
    }

    private func record(_ status: CalorieBudgetStatus, on date: Date) {
        defaults.set(status.rawValue, forKey: Key.lastStatus)
        defaults.set(HistoryCalendar.identifier(for: date), forKey: Key.lastStatusDay)
    }
}
