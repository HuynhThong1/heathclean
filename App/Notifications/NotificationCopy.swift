import Domain
import Foundation

/// What a `PlannedNotification` says. Vietnamese-primary, like every other
/// string in the app, and kept out of Domain for the reason
/// `VietnameseCopy.swift` records.
///
/// **A notification is not a place to give advice.** §18 rules out telling the
/// user whether to eat, and §0.3 rules out drawing over-budget as an alarm — so
/// every line here states a figure and stops. The one exception is the meal
/// reminder, which asks the user to do something because that is the whole of
/// what the switch offers.
enum NotificationCopy {
    @MainActor
    static func content(
        for kind: PlannedNotification.Kind,
        summary: DailyNutritionSummary
    ) -> (title: String, body: String) {
        let eaten = AppNumber.int(summary.consumedCalories)
        let target = AppNumber.int(summary.goal.calories)

        switch kind {
        case .budget(let status):
            return (
                title: title(for: status),
                // The same sentence at every rung: the title says which
                // threshold, the body says where the day actually stands, and
                // neither repeats the other.
                body: L("Đã ăn \(eaten) / \(target) kcal.")
            )
        case .mealReminder:
            return (
                title: L("Chưa có bữa nào hôm nay"),
                body: L("Ghi lại bữa ăn để theo dõi calo trong ngày.")
            )
        case .dailySummary:
            let protein = AppNumber.int(summary.consumedProtein)
            return (
                title: L("Tóm tắt hôm nay"),
                body: L("Đã ăn \(eaten) / \(target) kcal · \(protein) g đạm.")
            )
        }
    }

    @MainActor
    private static func title(for status: CalorieBudgetStatus) -> String {
        switch status {
        case .normal:
            // Unreachable: `budgetAlert` is silent below the first threshold.
            return L("Hôm nay")
        case .informUser:
            return L("Đã dùng 70% ngân sách calo")
        case .nearTarget:
            return L("Gần mục tiêu calo hôm nay")
        case .reached:
            return L("Đã đạt mục tiêu calo hôm nay")
        case .exceeded:
            return L("Đã vượt mục tiêu calo hôm nay")
        }
    }
}
