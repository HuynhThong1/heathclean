import Domain
import Foundation

@MainActor
@Observable
final class ScanModel {
    /// §10's state machine. `review` holds the model's proposal — nothing is
    /// written until the user confirms it (§10, "Nothing is written until the
    /// user confirms").
    ///
    /// **There is no `failed` case, and that is the point.** A failed analysis
    /// used to replace the whole screen with a dark error state whose only exits
    /// threw the photo away — so a photo that could not be analysed could not be
    /// logged at all, even though the user had already taken it and knew
    /// perfectly well what was on the plate. A failure now lands on `review`
    /// with no foods and `analysisFailure` set: same photo, same confirm button,
    /// and the items are typed in instead of proposed.
    enum State: Equatable {
        case idle
        case analyzing
        case review(FoodAnalysisResult)
    }

    private(set) var state: State = .idle
    private(set) var isSaving = false
    var editingFoodID: RecognizedFood.ID?

    /// Why the analysis produced nothing, when it did — the sentence the review
    /// screen shows above the photo. `nil` after a successful analysis, so it is
    /// also what tells the two kinds of review screen apart.
    private(set) var analysisFailure: String?

    /// A save that did not land. Shown *on* the review screen rather than
    /// replacing it: the corrections and the typed-in figures are all still
    /// there, and a retry is one tap. Losing them to an error screen is the same
    /// mistake the deleted `failed` state made.
    private(set) var saveError: String?

    /// Whether re-running the analysis on the photo already in hand is offered.
    ///
    /// Only while nothing is on the list. A retry replaces the whole result, so
    /// once anything has been typed in there is work to lose — and this app asks
    /// before losing work rather than after. Retaking the photo (`Quét lại`)
    /// still goes through the review screen's own confirmation.
    var canRetryAnalysis: Bool {
        analysisFailure != nil && foods.isEmpty && analyzedImage != nil
    }

    /// `var` because §6.8 lets the review screen change it. It has to be
    /// changeable there: the scan opens on `MealType.suggestedForNow()`, so a
    /// late lunch scanned at 15:10 arrives as "Bữa phụ", and without this the
    /// only way out was to cancel the scan and come back at a different hour.
    private(set) var type: MealType
    private let recognitionRepository: any FoodRecognitionRepository
    private let saveMeal: SaveMealUseCase
    private let photoStore: MealPhotoStore

    /// The normalized bytes that were analysed, kept so a confirmed meal can keep
    /// its picture (§32.4) and so §6.8 can show what was scanned.
    ///
    /// **In memory only, and written nowhere until the user confirms.** That is
    /// what makes "ảnh camera tạm phải bị xóa khi hủy luồng scan" true by
    /// construction: cancelling drops the reference, because there was never a
    /// file to clean up.
    private(set) var analyzedImage: Data?

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
    /// zero, so saving would quietly under-count the meal — and while anything
    /// is nameless, which only a hand-typed food can be.
    var canConfirm: Bool {
        guard let result, !result.foods.isEmpty, !isSaving else { return false }
        return result.foods.allSatisfy { $0.isResolved && $0.hasName }
    }

    var blockedReason: String? {
        guard let result, !isSaving else { return nil }
        if result.foods.isEmpty {
            // After a failure the note above the photo already says what
            // happened and offers the one action there is, so a second red line
            // under the total would only repeat it.
            guard analysisFailure == nil else { return nil }
            return L("Không nhận ra món nào. Thử chụp lại hoặc thêm món bằng tay.")
        }
        if result.foods.contains(where: { !$0.hasName }) {
            return L("Nhập tên món trước khi lưu")
        }
        if result.foods.contains(where: { !$0.isResolved }) {
            // Names the action that actually works. It used to say "sửa", which
            // invited renaming — and renaming never resolves anything.
            return L("Nhập dinh dưỡng hoặc bỏ món chưa rõ trước khi lưu")
        }
        return nil
    }

    func analyze(image: Data, mimeType: String = "image/jpeg") async {
        analyzedImage = image
        analysisFailure = nil
        saveError = nil
        state = .analyzing
        do {
            let result = try await recognitionRepository.analyze(image: image, mimeType: mimeType)
            state = .review(result)
        } catch let error as FoodRecognitionError {
            failAnalysis(Self.message(for: error))
        } catch {
            failAnalysis(L("Không phân tích được ảnh. Vui lòng thử lại."))
        }
    }

    /// The photo survives the failure, so the flow does too: an empty review is
    /// a screen the user can still finish, and `provider` is blank because no
    /// model contributed anything to it.
    private func failAnalysis(_ message: String) {
        analysisFailure = message
        state = .review(FoodAnalysisResult(foods: [], provider: ""))
    }

    /// Spends another analysis on the bytes already in hand, rather than sending
    /// the user back to the camera to re-take a photo that was fine.
    func retryAnalysis() async {
        guard canRetryAnalysis, let analyzedImage else { return }
        await analyze(image: analyzedImage)
    }

    /// Adds an empty food for the user to fill in, and opens the editor on it.
    ///
    /// It is unresolved and nameless, so `canConfirm` stays false until both are
    /// supplied — and the editor opens straight away because a card with no name
    /// and no figures is not something to leave sitting on the screen.
    func addFoodByHand() {
        guard case var .review(result) = state else { return }
        let food = RecognizedFood.typedByHand()
        result.foods.append(food)
        state = .review(result)
        editingFoodID = food.id
    }

    private static func message(for error: FoodRecognitionError) -> String {
        switch error {
        case .modelUnavailable:
            L("Dịch vụ nhận diện đang bận. Thử lại sau ít phút.")
        case .unreachable:
            L("Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.")
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
        fat: Double,
        fiber: Double? = nil
    ) {
        guard case var .review(result) = state,
              let index = result.foods.firstIndex(where: { $0.id == id })
        else { return }
        result.foods[index] = result.foods[index].resolved(
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            fiber: fiber
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
        analysisFailure = nil
        saveError = nil
    }

    private func storedPhoto(capturedAt: Date) async -> MealPhoto? {
        guard let analyzedImage else { return nil }
        return try? await photoStore.save(analyzedImage, capturedAt: capturedAt)
    }

    /// Returns the saved calories so the caller can raise the §6.14 toast.
    func confirm() async -> Double? {
        guard canConfirm, let result else { return nil }
        isSaving = true
        saveError = nil
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
            // Stays on the review screen with everything intact — see
            // `saveError`.
            saveError = L("Không lưu được bữa ăn. Vui lòng thử lại.")
            return nil
        }
    }
}
