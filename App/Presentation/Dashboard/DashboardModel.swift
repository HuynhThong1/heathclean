import Domain
import Foundation

@MainActor
@Observable
final class DashboardModel {
    private(set) var summary: DailyNutritionSummary?
    private(set) var profile: UserProfile?
    private(set) var errorMessage: String?

    private(set) var health: HealthSnapshot?

    private let userRepository: any UserRepository
    private let healthRepository: any HealthRepository
    private let getDailySummary: GetDailySummaryUseCase
    private let evaluateCalorieBudget: EvaluateCalorieBudgetUseCase
    private let calculateBMI: CalculateBMIUseCase
    private let notifications: NotificationCoordinator

    init(
        userRepository: any UserRepository,
        healthRepository: any HealthRepository,
        getDailySummary: GetDailySummaryUseCase,
        evaluateCalorieBudget: EvaluateCalorieBudgetUseCase,
        calculateBMI: CalculateBMIUseCase,
        notifications: NotificationCoordinator
    ) {
        self.userRepository = userRepository
        self.healthRepository = healthRepository
        self.getDailySummary = getDailySummary
        self.evaluateCalorieBudget = evaluateCalorieBudget
        self.calculateBMI = calculateBMI
        self.notifications = notifications
    }

    var status: CalorieBudgetStatus {
        guard let summary else { return .normal }
        return evaluateCalorieBudget.execute(budget: summary.budget)
    }

    var statusMessage: String? {
        guard let summary else { return nil }
        return evaluateCalorieBudget.message(for: summary.budget)
    }

    var bmi: BMI? {
        profile.map(calculateBMI.execute(profile:))
    }

    func load() async {
        do {
            guard let stored = try await userRepository.load() else { return }
            profile = stored.profile
            summary = try await getDailySummary.execute(date: Date(), goal: stored.goal)
            errorMessage = nil
        } catch {
            errorMessage = L("Không tải được bữa ăn hôm nay.")
        }

        // Every way of changing today's figures from this screen — manual entry,
        // deleting a food, editing the goal — ends here, so this is the one hook
        // §19 needs rather than four at the call sites. The scan is the exception,
        // because the tab shell owns it; `MainTabView` re-plans for that.
        if let summary { await notifications.apply(summary: summary) }

        await loadHealth()
    }

    /// Health is loaded separately and never fails the screen. It is
    /// supplementary — meals and targets must render whether or not the user
    /// shared anything.
    private func loadHealth() async {
        guard healthRepository.isAvailable else { return }
        health = try? await healthRepository.snapshot(on: Date())
    }
}
