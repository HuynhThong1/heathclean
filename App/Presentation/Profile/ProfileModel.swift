import Domain
import Foundation

@MainActor
@Observable
final class ProfileModel {
    private(set) var profile: UserProfile?
    private(set) var goal: NutritionGoal?
    /// Whether Apple Health actually returned anything.
    private(set) var hasHealthData = false

    private let userRepository: any UserRepository
    private let healthRepository: any HealthRepository
    private let calculateBMI: CalculateBMIUseCase

    init(
        userRepository: any UserRepository,
        healthRepository: any HealthRepository,
        calculateBMI: CalculateBMIUseCase
    ) {
        self.userRepository = userRepository
        self.healthRepository = healthRepository
        self.calculateBMI = calculateBMI
    }

    var bmi: BMI? { profile.map(calculateBMI.execute(profile:)) }

    /// "30 tuổi · 170 cm · 70 kg" — the identity line from §6.13.
    var bodyLine: String? {
        guard let profile else { return nil }
        let weight = profile.weightKg.formatted(
            .number.precision(.fractionLength(0...1)).locale(Locale(identifier: "vi_VN"))
        )
        return "\(profile.age) tuổi · \(Int(profile.heightCm.rounded())) cm · \(weight) kg"
    }

    /// Kilograms between current and target weight. `nil` when maintaining, or
    /// when no target was set — there is nothing to count down to.
    var kilogramsToTarget: Double? {
        guard let profile, profile.goal != .maintain, let target = profile.targetWeightKg else {
            return nil
        }
        return abs(profile.weightKg - target)
    }

    /// §6.13 wants "Đã kết nối" or "Chưa kết nối". HealthKit never reveals
    /// whether a *read* was granted, so the only honest signal is whether any
    /// data actually came back.
    var healthStatusText: String {
        guard healthRepository.isAvailable else { return String(localized: "Không khả dụng trên thiết bị này") }
        return hasHealthData
            ? String(localized: "Đã kết nối · bước chân, năng lượng, giấc ngủ")
            : String(localized: "Chưa kết nối")
    }

    func load() async {
        if let stored = try? await userRepository.load() {
            profile = stored.profile
            goal = stored.goal
        }

        guard healthRepository.isAvailable else {
            hasHealthData = false
            return
        }
        let snapshot = try? await healthRepository.snapshot(on: Date())
        hasHealthData = snapshot.map { !$0.isEmpty } ?? false
    }
}
