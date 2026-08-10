import Domain
import Foundation

@MainActor
@Observable
final class InsightsModel {
    struct Day: Identifiable {
        let date: Date
        let calories: Double
        /// Days with nothing logged are drawn as an empty column and left out
        /// of the averages — an unlogged day is missing data, not a zero-calorie
        /// day, and averaging it in would understate every week.
        var isLogged: Bool { calories > 0 }

        var id: Date { date }
    }

    /// Seven days, oldest first, with the last being today (§6.12).
    private(set) var days: [Day] = []
    private(set) var dailyGoalCalories: Double = 0
    private(set) var weightSeries = WeightSeries(
        weekCount: InsightsModel.weightWeeks, points: []
    )
    private(set) var targetWeightKg: Double?
    private(set) var errorMessage: String?

    static let dayCount = 7
    static let weightWeeks = 6

    private let mealRepository: any MealRepository
    private let userRepository: any UserRepository
    private let getWeightSeries: GetWeightSeriesUseCase

    init(
        mealRepository: any MealRepository,
        userRepository: any UserRepository,
        getWeightSeries: GetWeightSeriesUseCase
    ) {
        self.mealRepository = mealRepository
        self.userRepository = userRepository
        self.getWeightSeries = getWeightSeries
    }

    func load(now: Date = Date()) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -(Self.dayCount - 1), to: today) ?? today

        do {
            let stored = try await userRepository.load()
            dailyGoalCalories = stored?.goal.calories ?? 0
            targetWeightKg = stored?.profile.targetWeightKg

            let meals = try await mealRepository.meals(from: start, to: end)
            let byDay = Dictionary(grouping: meals) { calendar.startOfDay(for: $0.date) }
            days = (0..<Self.dayCount).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                    return nil
                }
                let calories = byDay[date]?.reduce(0) { $0 + $1.calories } ?? 0
                return Day(date: date, calories: calories)
            }

            weightSeries = try await getWeightSeries.execute(
                endingOn: now, weeks: Self.weightWeeks
            )
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Không tải được thống kê.")
        }
    }

    // MARK: Derived figures

    private var loggedDays: [Day] { days.filter(\.isLogged) }

    var hasCalorieData: Bool { !loggedDays.isEmpty }

    /// Averaged over the days that were logged, not over seven.
    var averageCalories: Double {
        let logged = loggedDays
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.calories } / Double(logged.count)
    }

    /// A day counts only if something was logged — an empty day is not a day
    /// spent inside the budget.
    var daysWithinGoal: Int {
        guard dailyGoalCalories > 0 else { return 0 }
        return loggedDays.count { $0.calories <= dailyGoalCalories }
    }

    /// The chart's top. The goal line has to fit inside it, or a week spent
    /// under target would draw its dashed line off the top of the card.
    var chartCeiling: Double {
        let highest = days.map(\.calories).max() ?? 0
        return max(highest, dailyGoalCalories, 1)
    }
}
