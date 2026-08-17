import Domain
import Foundation

@MainActor
@Observable
final class DashboardModel {
    private(set) var summary: DailyNutritionSummary?
    private(set) var profile: UserProfile?
    private(set) var errorMessage: String?

    private(set) var health: HealthSnapshot?

    /// Today's water, and the drinks behind it (Phase 5).
    ///
    /// Its own property rather than a field on `DailyNutritionSummary`: water is
    /// not part of a meal, so it does not come from `GetDailySummaryUseCase` and
    /// folding it in would mean a summary that is partly meals and partly not.
    private(set) var water: DailyWater?

    private let userRepository: any UserRepository
    private let healthRepository: any HealthRepository
    private let getDailySummary: GetDailySummaryUseCase
    private let evaluateCalorieBudget: EvaluateCalorieBudgetUseCase
    private let calculateBMI: CalculateBMIUseCase
    private let getDailyWater: GetDailyWaterUseCase
    private let logWater: LogWaterUseCase
    private let notifications: NotificationCoordinator

    init(
        userRepository: any UserRepository,
        healthRepository: any HealthRepository,
        getDailySummary: GetDailySummaryUseCase,
        evaluateCalorieBudget: EvaluateCalorieBudgetUseCase,
        calculateBMI: CalculateBMIUseCase,
        getDailyWater: GetDailyWaterUseCase,
        logWater: LogWaterUseCase,
        notifications: NotificationCoordinator
    ) {
        self.userRepository = userRepository
        self.healthRepository = healthRepository
        self.getDailySummary = getDailySummary
        self.evaluateCalorieBudget = evaluateCalorieBudget
        self.calculateBMI = calculateBMI
        self.getDailyWater = getDailyWater
        self.logWater = logWater
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

        await loadWater()
        await loadHealth()
    }

    // MARK: Water

    /// Water never fails the screen, the same rule health follows: a store that
    /// cannot answer costs the water card and nothing else.
    private func loadWater() async {
        guard let target = summary?.goal.waterMillilitres else { return }
        water = try? await getDailyWater.execute(on: Date(), target: target)
    }

    /// Adds a drink and re-reads the day.
    ///
    /// Re-reads rather than adding to the local total: the write is what makes
    /// it true, and a card that moved before the store agreed would show a
    /// figure that a failed write silently invents.
    func drink(_ serving: WaterServing) async {
        try? await logWater.execute(millilitres: serving.millilitres, on: Date())
        await loadWater()
    }

    /// Takes back the drink that was logged last. Nothing to undo is not an
    /// error — the button is hidden then anyway.
    ///
    /// A failure **says so**. Every other write on this screen can be seen to
    /// have worked or not by the figure moving; an undo that silently does
    /// nothing looks exactly like a button that is not wired up, which is how
    /// this one spent an afternoon being debugged.
    func undoLastDrink() async {
        guard let entry = water?.mostRecent else { return }
        do {
            try await logWater.undo(entry)
        } catch {
            waterErrorMessage = L("Không hoàn tác được: \(error.localizedDescription)")
        }
        await loadWater()
    }

    private(set) var waterErrorMessage: String?

    /// Health is loaded separately and never fails the screen. It is
    /// supplementary — meals and targets must render whether or not the user
    /// shared anything.
    private func loadHealth() async {
        guard healthRepository.isAvailable else { return }
        health = try? await healthRepository.snapshot(on: Date())
    }
}
