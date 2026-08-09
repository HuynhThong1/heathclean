import Domain
import Foundation

@MainActor
@Observable
final class DashboardModel {
    private(set) var summary: DailyNutritionSummary?
    private(set) var profile: UserProfile?
    private(set) var errorMessage: String?

    private let userRepository: any UserRepository
    private let getDailySummary: GetDailySummaryUseCase
    private let evaluateCalorieBudget: EvaluateCalorieBudgetUseCase
    private let calculateBMI: CalculateBMIUseCase

    init(
        userRepository: any UserRepository,
        getDailySummary: GetDailySummaryUseCase,
        evaluateCalorieBudget: EvaluateCalorieBudgetUseCase,
        calculateBMI: CalculateBMIUseCase
    ) {
        self.userRepository = userRepository
        self.getDailySummary = getDailySummary
        self.evaluateCalorieBudget = evaluateCalorieBudget
        self.calculateBMI = calculateBMI
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
            errorMessage = "Could not load today's meals."
        }
    }
}
