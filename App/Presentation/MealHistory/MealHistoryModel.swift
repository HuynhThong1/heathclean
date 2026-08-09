import Domain
import Foundation

@MainActor
@Observable
final class MealHistoryModel {
    struct Day: Identifiable {
        let date: Date
        let meals: [Meal]

        var id: Date { date }
        var calories: Double { meals.reduce(0) { $0 + $1.calories } }
    }

    private(set) var days: [Day] = []
    private(set) var errorMessage: String?

    private let mealRepository: any MealRepository

    init(mealRepository: any MealRepository) {
        self.mealRepository = mealRepository
    }

    func load(daysBack: Int = 30) async {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60)
        let start = calendar.date(byAdding: .day, value: -daysBack, to: end) ?? end

        do {
            let meals = try await mealRepository.meals(from: start, to: end)
            days = Dictionary(grouping: meals) { calendar.startOfDay(for: $0.date) }
                .map { Day(date: $0.key, meals: $0.value.sorted { $0.date < $1.date }) }
                .sorted { $0.date > $1.date }
            errorMessage = nil
        } catch {
            errorMessage = "Could not load your meal history."
        }
    }
}
