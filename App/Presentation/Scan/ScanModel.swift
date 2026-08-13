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

    /// `var` because §6.8 lets the review screen change it. It has to be
    /// changeable there: the scan opens on `MealType.suggestedForNow()`, so a
    /// late lunch scanned at 15:10 arrives as "Bữa phụ", and without this the
    /// only way out was to cancel the scan and come back at a different hour.
    private(set) var type: MealType
    private let recognitionRepository: any FoodRecognitionRepository
    private let saveMeal: SaveMealUseCase
    private let photoStore: MealPhotoStore

    /// The normalized bytes that were analysed, kept so a confirmed meal can keep
    /// its picture (§32.4).
    ///
    /// **In memory only, and written nowhere until the user confirms.** That is
    /// what makes "ảnh camera tạm phải bị xóa khi hủy luồng scan" true by
    /// construction: cancelling drops the reference, because there was never a
    /// file to clean up.
    private var analyzedImage: Data?

    init(
        type: MealType,
        recognitionRepository: any FoodRecognitionRepository,
        saveMeal: SaveMealUseCase,
        photoStore: MealPhotoStore
    ) {
        self.type = type
        self.recognitionRepository = recognitionRepository
        self.saveMeal = saveMeal
        self.photoStore = photoStore
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
            // Names the action that actually works. It used to say "sửa", which
            // invited renaming — and renaming never resolves anything.
            return "Nhập dinh dưỡng hoặc bỏ món chưa rõ trước khi lưu"
        }
        return nil
    }

    func analyze(image: Data, mimeType: String = "image/jpeg") async {
        analyzedImage = image
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

    /// §6.8's "đổi bữa": breakfast → lunch → snack → dinner → breakfast. The
    /// wrap comes from `MealType.allCases`, which is declared in that order.
    func cycleMealType() {
        let all = MealType.allCases
        guard let index = all.firstIndex(of: type) else { return }
        type = all[(index + 1) % all.count]
    }

    /// Nutrition the database did not have, for the portion currently shown.
    ///
    /// This is the only way an unresolved food ever resolves. `rename` cannot do
    /// it — the gateway decided `isResolved` and the client does not look names
    /// up — so without this, confirming stays blocked forever on any dish
    /// outside the nutrition table.
    func supplyNutrition(
        for id: RecognizedFood.ID,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double
    ) {
        guard case var .review(result) = state,
              let index = result.foods.firstIndex(where: { $0.id == id })
        else { return }
        result.foods[index] = result.foods[index].resolved(
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat
        )
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
        analyzedImage = nil
    }

    private func storedPhoto(capturedAt: Date) async -> MealPhoto? {
        guard let analyzedImage else { return nil }
        return try? await photoStore.save(analyzedImage, capturedAt: capturedAt)
    }

    /// Returns the saved calories so the caller can raise the §6.14 toast.
    func confirm() async -> Double? {
        guard canConfirm, let result else { return nil }
        isSaving = true
        defer { isSaving = false }

        let now = Date()
        // Bytes first, row second (§32.4). A photo that cannot be written does
        // not fail the meal — the meal is the thing the user came to log, the way
        // a failed weight write does not fail a profile save.
        let photos = await storedPhoto(capturedAt: now).map { [$0] } ?? []

        let meal = Meal(
            date: now,
            type: type,
            items: result.foods.map(\.foodItem),
            photos: photos
        )
        do {
            try await saveMeal.execute(meal)
            return result.totalCalories
        } catch {
            // The row never landed, so the bytes must not stay: nothing would
            // ever point at them again.
            await photoStore.delete(ids: photos.map(\.id))
            state = .failed(String(localized: "Không lưu được bữa ăn. Vui lòng thử lại."))
            return nil
        }
    }
}
