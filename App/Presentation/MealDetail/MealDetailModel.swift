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
    private let photoStore: MealPhotoStore

    init(
        type: MealType,
        meals: [Meal],
        dailyGoalCalories: Double,
        mealRepository: any MealRepository,
        removeFoodItem: RemoveFoodItemUseCase,
        photoStore: MealPhotoStore
    ) {
        self.type = type
        self.meals = meals
        self.dailyGoalCalories = dailyGoalCalories
        self.mealRepository = mealRepository
        self.removeFoodItem = removeFoodItem
        self.photoStore = photoStore
    }

    var items: [FoodItem] { meals.flatMap(\.items) }

    /// The photos of this meal — usually none, since only a scan produces one.
    /// A detail screen can cover several meals of the same type on one day, so
    /// this is every photo across them, in the order they were eaten.
    var photos: [MealPhoto] { meals.flatMap(\.photos) }

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
        return AppDate.time(for: loggedAt)
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
            case let .mealDeleted(photoIDs):
                // The row is gone, so its bytes have to go too — nothing else
                // will ever reference them, and until the next launch's sweep
                // nothing else would notice.
                await photoStore.delete(ids: photoIDs)
                meals.removeAll { $0.id == owner.id }
                return meals.isEmpty ? .mealDeleted : .itemRemoved
            case .notFound:
                return .unchanged
            }
        } catch {
            errorMessage = L("Không xoá được món. Vui lòng thử lại.")
            return .unchanged
        }
    }

    func delete() async -> Bool {
        do {
            var photoIDs: [UUID] = []
            for meal in meals {
                photoIDs += try await mealRepository.delete(mealID: meal.id)
            }
            await photoStore.delete(ids: photoIDs)
            meals = []
            return true
        } catch {
            errorMessage = L("Không xoá được bữa ăn. Vui lòng thử lại.")
            return false
        }
    }
}
