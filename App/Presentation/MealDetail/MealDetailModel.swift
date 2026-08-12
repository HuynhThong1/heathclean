import Domain
import Foundation

@MainActor
@Observable
final class MealDetailModel {
    enum ItemRemovalResult {
        case itemRemoved
        case mealDeleted
        case unchanged
    }

    private(set) var meals: [Meal]
    var errorMessage: String?
    var isConfirmingDelete = false

    let type: MealType
    private let dailyGoalCalories: Double
    private let mealRepository: any MealRepository
    private let removeFoodItem: RemoveFoodItemUseCase

    init(
        type: MealType,
        meals: [Meal],
        dailyGoalCalories: Double,
        mealRepository: any MealRepository,
        removeFoodItem: RemoveFoodItemUseCase
    ) {
        self.type = type
        self.meals = meals
        self.dailyGoalCalories = dailyGoalCalories
        self.mealRepository = mealRepository
        self.removeFoodItem = removeFoodItem
    }

    var items: [FoodItem] { meals.flatMap(\.items) }

    var totalCalories: Double { meals.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { meals.reduce(0) { $0 + $1.protein } }
    var totalCarbohydrates: Double { meals.reduce(0) { $0 + $1.carbohydrates } }
    var totalFat: Double { meals.reduce(0) { $0 + $1.fat } }

    /// Share of the day's budget this meal accounts for, 0…1.
    var budgetShare: Double {
        dailyGoalCalories > 0 ? totalCalories / dailyGoalCalories : 0
    }

    var budgetSharePercent: Int { Int((budgetShare * 100).rounded()) }

    /// When the meal was logged — the earliest entry if it was split.
    var loggedAt: Date? { meals.map(\.date).min() }

    var loggedAtText: String? {
        guard let loggedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: loggedAt)
    }

    /// Energy contributed by each macro, for the split bar (§6.10): protein and
    /// carbohydrates at 4 kcal/g, fat at 9. Shares are of that sum, not of the
    /// meal's stated calories — the two can differ when a food's numbers were
    /// entered by hand.
    var macroEnergyShares: (protein: Double, carbs: Double, fat: Double) {
        let protein = totalProtein * 4
        let carbs = totalCarbohydrates * 4
        let fat = totalFat * 9
        let total = protein + carbs + fat
        guard total > 0 else { return (0, 0, 0) }
        return (protein / total, carbs / total, fat / total)
    }

    /// The food the user is being asked about, or `nil` when nothing is pending.
    /// One optional rather than a Bool plus a separate id, so the sheet cannot be
    /// shown without knowing which food it is about.
    var itemPendingRemoval: FoodItem?

    /// Removes one food and tells the view whether it should refresh its parent
    /// or leave a detail screen that no longer has anything to show.
    func removeItem(_ item: FoodItem) async -> ItemRemovalResult {
        guard let owner = meals.first(where: { meal in meal.items.contains { $0.id == item.id } })
        else { return .unchanged }

        do {
            switch try await removeFoodItem.execute(itemID: item.id, from: owner) {
            case let .itemRemoved(updated):
                if let index = meals.firstIndex(where: { $0.id == updated.id }) {
                    meals[index] = updated
                }
                return .itemRemoved
            case .mealDeleted:
                meals.removeAll { $0.id == owner.id }
                return meals.isEmpty ? .mealDeleted : .itemRemoved
            case .notFound:
                return .unchanged
            }
        } catch {
            errorMessage = String(localized: "Không xoá được món. Vui lòng thử lại.")
            return .unchanged
        }
    }

    func delete() async -> Bool {
        do {
            for meal in meals {
                try await mealRepository.delete(mealID: meal.id)
            }
            meals = []
            return true
        } catch {
            errorMessage = String(localized: "Không xoá được bữa ăn. Vui lòng thử lại.")
            return false
        }
    }
}
