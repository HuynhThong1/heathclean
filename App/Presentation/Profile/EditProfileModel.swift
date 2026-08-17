import Domain
import Foundation

/// PROFILE_SPEC §5 — the state behind "Sửa hồ sơ".
///
/// Every field recomputes the calorie target **immediately**, which is the one
/// rule the whole screen is built around: the user sees the consequence before
/// they commit to it, and "Lưu" then confirms a number they have already read
/// rather than revealing one.
///
/// **The save routes through `OnboardingModel`**, which is not laziness. Weight
/// history is written from exactly one place — `OnboardingModel.save()`, which
/// calls `RecordWeightUseCase` after the profile lands — and a second writer is
/// how a weighing quietly stops being recorded on one of the two paths. This
/// model owns the draft and the arithmetic; it hands the draft to the one writer
/// there has ever been.
@MainActor
@Observable
final class EditProfileModel {
    // MARK: Draft

    var biologicalSex: BiologicalSex? { didSet { note(.sex, oldValue != biologicalSex) } }
    var age: Int { didSet { note(.age, oldValue != age) } }
    var heightCm: Double { didSet { note(.height, oldValue != heightCm) } }
    var weightKg: Double { didSet { note(.weight, oldValue != weightKg) } }
    var goal: WeightGoal { didSet { note(.goal, oldValue != goal) } }
    var targetWeightKg: Double? { didSet { note(.targetWeight, oldValue != targetWeightKg) } }
    var activityLevel: ActivityLevel { didSet { note(.activity, oldValue != activityLevel) } }

    /// What the profile looked like when the screen opened. The goal card
    /// quotes it ("Trước đây 2.050 kcal") and `isDirty` is measured against it.
    private(set) var original: UserProfile?
    private(set) var originalGoal: NutritionGoal?

    /// Which field was touched last, so the goal card can say *why* the number
    /// moved. Naming the most recent edit is what "vừa sửa" means; listing every
    /// difference would turn a one-line caption into a changelog.
    private(set) var lastChanged: EditField?

    private(set) var isSaving = false
    private(set) var didSave = false
    var errorMessage: String?

    private let writer: OnboardingModel
    private let userRepository: any UserRepository
    private let calculateCalorieGoal: CalculateCalorieGoalUseCase

    init(
        writer: OnboardingModel,
        userRepository: any UserRepository,
        calculateCalorieGoal: CalculateCalorieGoalUseCase
    ) {
        self.writer = writer
        self.userRepository = userRepository
        self.calculateCalorieGoal = calculateCalorieGoal

        // The onboarding defaults, so the form is never empty while loading.
        self.biologicalSex = nil
        self.age = 30
        self.heightCm = 170
        self.weightKg = 70
        self.goal = .maintain
        self.targetWeightKg = nil
        self.activityLevel = .moderate
    }

    enum EditField: Hashable {
        case sex, age, height, weight, goal, targetWeight, activity
    }

    /// `didSet` fires on every assignment, including a binding writing back the
    /// value it already held; only a real change should move the caption.
    private func note(_ field: EditField, _ changed: Bool) {
        guard changed, original != nil else { return }
        lastChanged = field
    }

    // MARK: Loading

    func load() async {
        guard let stored = try? await userRepository.load() else { return }
        apply(stored.profile)
        original = stored.profile
        originalGoal = stored.goal
        lastChanged = nil
    }

    private func apply(_ profile: UserProfile) {
        biologicalSex = profile.biologicalSex
        age = profile.age
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        goal = profile.goal
        targetWeightKg = profile.targetWeightKg
        activityLevel = profile.activityLevel
    }

    // MARK: Derived

    var profile: UserProfile {
        UserProfile(
            id: original?.id ?? UUID(),
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            biologicalSex: biologicalSex,
            activityLevel: activityLevel,
            goal: goal,
            targetWeightKg: goal == .maintain ? nil : targetWeightKg
        )
    }

    var nutritionGoal: NutritionGoal { calculateCalorieGoal.execute(profile: profile) }

    var basalMetabolicRate: Double {
        CalculateCalorieGoalUseCase.basalMetabolicRate(profile: profile)
    }

    var totalExpenditure: Double { basalMetabolicRate * activityLevel.multiplier }

    /// Whether the safety floor is what decided the target, rather than the
    /// arithmetic. §5 asks for the reason to be written out when it binds — a
    /// figure that stops responding to the slider is otherwise indistinguishable
    /// from a bug.
    var isClampedToFloor: Bool {
        totalExpenditure + goal.dailyCalorieDelta < nutritionGoal.calories - 0.5
    }

    /// Which floor caught it. Both are in `CalculateCalorieGoalUseCase`: a
    /// deficit never goes below the user's own basal rate, and never below the
    /// absolute minimum whatever the basal rate says.
    ///
    /// Read off the result rather than compared against the constant, which is
    /// `internal` to Domain: when the clamp binds, the target *is* whichever of
    /// the two floors won, so matching it against the basal rate identifies the
    /// winner without this file holding a second copy of a number that can
    /// drift out of step with the one that decides.
    var floorReason: FloorReason? {
        guard isClampedToFloor else { return nil }
        return abs(nutritionGoal.calories - basalMetabolicRate) < 0.5 ? .basalRate : .absoluteMinimum
    }

    enum FloorReason { case basalRate, absoluteMinimum }

    // MARK: Validity

    var isValid: Bool {
        OnboardingModel.heightRange.contains(heightCm)
            && OnboardingModel.weightRange.contains(weightKg)
            && OnboardingModel.ageRange.contains(age)
    }

    var isDirty: Bool {
        guard let original else { return false }
        return profile != original
    }

    var canSave: Bool { isDirty && isValid && !isSaving }

    // MARK: Safe range for the target weight (§5, state B)

    /// The lightest weight that still sits inside the healthy BMI band for this
    /// height. **Below it the screen says so and then gets out of the way** —
    /// §5 is explicit that this is not red, does not block "Lưu", and does not
    /// tell the user what to do.
    var safeMinimumTargetKg: Double? {
        let metres = heightCm / 100
        guard metres > 0 else { return nil }
        return 18.5 * metres * metres
    }

    var isTargetBelowSafeRange: Bool {
        guard let target = targetWeightKg, let minimum = safeMinimumTargetKg, goal == .lose
        else { return false }
        return target < minimum
    }

    /// The alternative the note offers. BMI 20.5 — inside the band rather than
    /// on its edge, so accepting the suggestion does not land the user back on
    /// the boundary — rounded to the half kilogram the field is written in.
    var suggestedTargetKg: Double? {
        let metres = heightCm / 100
        guard metres > 0 else { return nil }
        return (20.5 * metres * metres * 2).rounded() / 2
    }

    // MARK: Saving

    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // The one writer: it saves the profile and records the weighing, and a
        // failed weighing does not report the profile as unsaved.
        writer.apply(profile)
        guard await writer.save() else {
            errorMessage = writer.errorMessage ?? L("Không lưu được hồ sơ. Vui lòng thử lại.")
            return false
        }
        didSave = true
        return true
    }
}
