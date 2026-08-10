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

    /// Connecting is optional; declining must not block onboarding, so a failure
    /// here is recorded and moved past rather than surfaced as an error.
    func connectAppleHealth() async {
        guard !isConnectingHealth else { return }
        isConnectingHealth = true
        defer { isConnectingHealth = false }

        do {
            try await healthRepository.requestAuthorization()
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
            : "Enter a height between \(Int(Self.heightRange.lowerBound)) and \(Int(Self.heightRange.upperBound)) cm"
    }

    var weightError: String? {
        Self.weightRange.contains(weightKg)
            ? nil
            : "Enter a weight between \(Int(Self.weightRange.lowerBound)) and \(Int(Self.weightRange.upperBound)) kg"
    }

    /// Target weight is optional, but a value pointing the wrong way is worth
    /// flagging — it silently produces a goal the user did not intend.
    var targetWeightHint: String? {
        guard let target = targetWeightKg else { return nil }
        switch goal {
        case .lose where target >= weightKg:
            return "For a weight-loss goal this is usually below your current weight."
        case .gain where target <= weightKg:
            return "For a weight-gain goal this is usually above your current weight."
        default:
            return nil
        }
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
