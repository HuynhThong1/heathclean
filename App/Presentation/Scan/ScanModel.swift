import Domain
import Foundation

@MainActor
@Observable
final class ScanModel {
    /// §10's state machine. `review` holds the model's proposal — nothing is
    /// written until the user confirms it (§10, "Nothing is written until the
    /// user confirms").
    enum State: Equatable {
        case idle
        case analyzing
        case review(FoodAnalysisResult)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var isSaving = false
    var editingFoodID: RecognizedFood.ID?

    let type: MealType
    private let recognitionRepository: any FoodRecognitionRepository
    private let saveMeal: SaveMealUseCase

    init(
        type: MealType,
        recognitionRepository: any FoodRecognitionRepository,
        saveMeal: SaveMealUseCase
    ) {
        self.type = type
        self.recognitionRepository = recognitionRepository
        self.saveMeal = saveMeal
    }

    var foods: [RecognizedFood] {
        if case let .review(result) = state { return result.foods }
        return []
    }

    var result: FoodAnalysisResult? {
        if case let .review(result) = state { return result }
        return nil
    }

    var editingFood: RecognizedFood? {
        guard let editingFoodID else { return nil }
        return foods.first { $0.id == editingFoodID }
    }

    /// Confirming is blocked while anything is unresolved — its nutrition is
    /// zero, so saving would quietly under-count the meal.
    var canConfirm: Bool {
        guard let result, !result.foods.isEmpty, !isSaving else { return false }
        return result.foods.allSatisfy(\.isResolved)
    }

    var blockedReason: String? {
        guard let result, !isSaving else { return nil }
        if result.foods.isEmpty { return "Không nhận ra món nào. Thử chụp lại hoặc nhập tay." }
        if result.foods.contains(where: { !$0.isResolved }) {
            return "Sửa hoặc bỏ món chưa rõ trước khi lưu"
        }
        return nil
    }

    func analyze(image: Data, mimeType: String = "image/jpeg") async {
        state = .analyzing
        do {
            let result = try await recognitionRepository.analyze(image: image, mimeType: mimeType)
            state = .review(result)
        } catch let error as FoodRecognitionError {
            state = .failed(Self.message(for: error))
        } catch {
            state = .failed(String(localized: "Không phân tích được ảnh. Vui lòng thử lại."))
        }
    }

    private static func message(for error: FoodRecognitionError) -> String {
        switch error {
        case .modelUnavailable:
            String(localized: "Dịch vụ nhận diện đang bận. Thử lại sau ít phút.")
        case .unreachable:
            String(localized: "Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.")
        case let .rejected(reason):
            reason
        }
    }

    func updateWeight(of id: RecognizedFood.ID, to grams: Double) {
        guard case var .review(result) = state,
              let index = result.foods.firstIndex(where: { $0.id == id })
        else { return }
        result.foods[index] = result.foods[index].scaled(toWeightGrams: grams)
        state = .review(result)
    }

    func rename(_ id: RecognizedFood.ID, to name: String) {
        guard case var .review(result) = state,
              let index = result.foods.firstIndex(where: { $0.id == id })
        else { return }
        result.foods[index].name = name
        state = .review(result)
    }

    func remove(_ id: RecognizedFood.ID) {
        guard case var .review(result) = state else { return }
        result.foods.removeAll { $0.id == id }
        state = .review(result)
    }

    func reset() {
        state = .idle
        editingFoodID = nil
    }

    /// Returns the saved calories so the caller can raise the §6.14 toast.
    func confirm() async -> Double? {
        guard canConfirm, let result else { return nil }
        isSaving = true
        defer { isSaving = false }

        let meal = Meal(date: Date(), type: type, items: result.foods.map(\.foodItem))
        do {
            try await saveMeal.execute(meal)
            return result.totalCalories
        } catch {
            state = .failed(String(localized: "Không lưu được bữa ăn. Vui lòng thử lại."))
            return nil
        }
    }
}
