import Domain
import Foundation

@MainActor
@Observable
final class MealEntryModel {
    /// One row of the entry form. Held separately from `FoodItem` so a
    /// half-typed row is never a Domain value.
    struct Draft: Identifiable {
        let id = UUID()
        var name = ""
        var weightGrams = 100.0
        var calories = 0.0
        var protein = 0.0
        var carbohydrates = 0.0
        var fat = 0.0

        var isComplete: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && weightGrams > 0
                && calories >= 0
        }

        var foodItem: FoodItem {
            FoodItem(
                id: id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                weightGrams: weightGrams,
                calories: calories,
                protein: protein,
                carbohydrates: carbohydrates,
                fat: fat
            )
        }
    }

    let type: MealType
    var drafts: [Draft] = [Draft()]
    var errorMessage: String?
    private(set) var isSaving = false

    private let date: Date
    private let saveMeal: SaveMealUseCase

    init(type: MealType, date: Date, saveMeal: SaveMealUseCase) {
        self.type = type
        self.date = date
        self.saveMeal = saveMeal
    }

    var totalCalories: Double { drafts.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { drafts.reduce(0) { $0 + $1.protein } }
    var totalCarbohydrates: Double { drafts.reduce(0) { $0 + $1.carbohydrates } }
    var totalFat: Double { drafts.reduce(0) { $0 + $1.fat } }

    var canSave: Bool {
        !drafts.isEmpty && drafts.allSatisfy(\.isComplete) && hasCalories && !isSaving
    }

    /// §10: saving stays disabled until at least one item carries calories —
    /// a meal of zero kcal is almost always an unfinished entry.
    var hasCalories: Bool {
        drafts.contains { $0.calories > 0 }
    }

    /// Explains a disabled Save rather than leaving it inert.
    var blockedReason: String? {
        guard !isSaving else { return nil }
        if drafts.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return L("Nhập tên món trước khi lưu")
        }
        if !hasCalories {
            return L("Nhập calo trước khi lưu")
        }
        return nil
    }

    func addDraft() {
        drafts.append(Draft())
    }

    func removeDrafts(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }

    func save() async -> Bool {
        guard canSave else { return false }

        isSaving = true
        defer { isSaving = false }

        let meal = Meal(date: date, type: type, items: drafts.map(\.foodItem))
        do {
            try await saveMeal.execute(meal)
            return true
        } catch {
            errorMessage = L("Không lưu được bữa ăn. Vui lòng thử lại.")
            return false
        }
    }
}
