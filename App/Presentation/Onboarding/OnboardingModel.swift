import Domain
import Foundation

@MainActor
@Observable
final class OnboardingModel {
    var age = 30
    var heightCm = 170.0
    var weightKg = 70.0
    var biologicalSex: BiologicalSex?
    var activityLevel: ActivityLevel = .moderate
    var goal: WeightGoal = .maintain
    var targetWeightKg: Double?

    var errorMessage: String?
    private(set) var isSaving = false

    private let userRepository: any UserRepository
    private let healthRepository: any HealthRepository
    private let calculateBMI: CalculateBMIUseCase
    private let calculateCalorieGoal: CalculateCalorieGoalUseCase

    init(
        userRepository: any UserRepository,
        healthRepository: any HealthRepository,
        calculateBMI: CalculateBMIUseCase,
        calculateCalorieGoal: CalculateCalorieGoalUseCase
    ) {
        self.userRepository = userRepository
        self.healthRepository = healthRepository
        self.calculateBMI = calculateBMI
        self.calculateCalorieGoal = calculateCalorieGoal
    }

    // MARK: Apple Health

    /// Hidden where there is no health store at all, e.g. iPad.
    var isHealthAvailable: Bool { healthRepository.isAvailable }

    private(set) var isConnectingHealth = false
    /// Set once the permission sheet has been through. It does **not** mean
    /// access was granted — HealthKit deliberately never reveals that for reads.
    private(set) var hasRequestedHealth = false

    /// Which types the permission screen will ask for. All on by default —
    /// the user turns off what they would rather not share.
    var requestedHealthKinds: Set<HealthDataKind> = Set(HealthDataKind.allCases)

    func setHealthKind(_ kind: HealthDataKind, requested: Bool) {
        if requested {
            requestedHealthKinds.insert(kind)
        } else {
            requestedHealthKinds.remove(kind)
        }
    }

    /// Connecting is optional; declining must not block onboarding, so a failure
    /// here is recorded and moved past rather than surfaced as an error.
    func connectAppleHealth() async {
        guard !isConnectingHealth else { return }
        isConnectingHealth = true
        defer { isConnectingHealth = false }

        do {
            try await healthRepository.requestAuthorization(for: requestedDataTypes)
            // Only on success. Declining inside the sheet still succeeds here —
            // HealthKit never reports a denied read — but a thrown error means
            // the request itself failed, and claiming "connected" would be a lie.
            hasRequestedHealth = true
        } catch {
            healthMessage = "Apple Health isn't available right now. You can connect it later."
        }
    }

    /// Shown only when the request itself failed; declining inside the sheet is
    /// silent by design.
    var healthMessage: String?

    private var requestedDataTypes: Set<HealthDataType> {
        Set(requestedHealthKinds.flatMap(\.dataTypes))
    }

    var profile: UserProfile {
        UserProfile(
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            biologicalSex: biologicalSex,
            activityLevel: activityLevel,
            goal: goal,
            targetWeightKg: goal == .maintain ? nil : targetWeightKg
        )
    }

    var bmi: BMI { calculateBMI.execute(profile: profile) }
    var nutritionGoal: NutritionGoal { calculateCalorieGoal.execute(profile: profile) }

    /// Onboarding cannot produce a sensible target outside these ranges.
    static let heightRange = 100.0...250.0
    static let weightRange = 25.0...400.0
    static let ageRange = 13...120

    var isValid: Bool {
        heightError == nil && weightError == nil && Self.ageRange.contains(age)
    }

    /// `nil` while the value is usable. The Continue button is disabled on the
    /// same conditions, so without these the user would see it grey out with no
    /// explanation.
    var heightError: String? {
        Self.heightRange.contains(heightCm)
            ? nil
            : "Nhập chiều cao từ \(Int(Self.heightRange.lowerBound)) đến \(Int(Self.heightRange.upperBound)) cm"
    }

    var weightError: String? {
        Self.weightRange.contains(weightKg)
            ? nil
            : "Nhập cân nặng từ \(Int(Self.weightRange.lowerBound)) đến \(Int(Self.weightRange.upperBound)) kg"
    }

    /// Target weight is optional, but a value pointing the wrong way is worth
    /// flagging — it silently produces a goal the user did not intend.
    var targetWeightHint: String? {
        guard let target = targetWeightKg else { return nil }
        switch goal {
        case .lose where target >= weightKg:
            return "Mục tiêu giảm cân thường thấp hơn cân nặng hiện tại."
        case .gain where target <= weightKg:
            return "Mục tiêu tăng cân thường cao hơn cân nặng hiện tại."
        default:
            return nil
        }
    }

    /// Seeds the form from a stored profile so the same four steps can edit it
    /// (§6.13 routes here). Without this, editing would silently reset every
    /// field to the first-run defaults.
    func apply(_ profile: UserProfile) {
        age = profile.age
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        biologicalSex = profile.biologicalSex
        activityLevel = profile.activityLevel
        goal = profile.goal
        targetWeightKg = profile.targetWeightKg
    }

    // MARK: Step navigation

    /// Which of the four steps is showing. The shell is one screen (§6.2).
    var step: OnboardingStep = .body

    /// Only step 1 can be invalid — every later step is a choice among valid
    /// options — so the CTA is gated on validity solely there.
    var canAdvance: Bool {
        step == .body ? isValid : true
    }

    func advance() {
        guard let next = step.next else { return }
        step = next
    }

    func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    /// The formula line under the result, e.g. "BMR 1.735 × vận động ×1,375 −500 kcal".
    var formulaLine: String {
        let bmr = CalculateCalorieGoalUseCase.basalMetabolicRate(profile: profile)
        let multiplier = activityLevel.multiplier
            .formatted(.number.precision(.fractionLength(0...3)).locale(Locale(identifier: "vi_VN")))
        let delta = goal.dailyCalorieDelta
        let deltaText = delta == 0
            ? "±0 kcal"
            : (delta < 0 ? "−\(VNNumber.int(abs(delta))) kcal" : "+\(VNNumber.int(delta)) kcal")
        return "BMR \(VNNumber.int(bmr)) × vận động ×\(multiplier) \(deltaText)"
    }

    /// Shown when the user leaves sex unspecified, so the lower confidence of
    /// the resulting target is not a surprise.
    var usesEstimatedSexConstant: Bool {
        biologicalSex == nil || biologicalSex == .preferNotToSay
    }

    func save() async -> Bool {
        guard isValid, !isSaving else { return false }

        isSaving = true
        defer { isSaving = false }

        do {
            try await userRepository.save(profile: profile, goal: nutritionGoal)
            return true
        } catch {
            errorMessage = "Could not save your profile. Please try again."
            return false
        }
    }
}
