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
    var isValid: Bool {
        (13...120).contains(age)
            && (100.0...250.0).contains(heightCm)
            && (25.0...400.0).contains(weightKg)
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
