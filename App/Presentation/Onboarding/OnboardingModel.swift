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
    private let calculateBMI: CalculateBMIUseCase
    private let calculateCalorieGoal: CalculateCalorieGoalUseCase

    init(
        userRepository: any UserRepository,
        calculateBMI: CalculateBMIUseCase,
        calculateCalorieGoal: CalculateCalorieGoalUseCase
    ) {
        self.userRepository = userRepository
        self.calculateBMI = calculateBMI
        self.calculateCalorieGoal = calculateCalorieGoal
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
