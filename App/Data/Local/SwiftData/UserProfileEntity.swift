import Domain
import Foundation
import SwiftData

/// Single-row store for the profile and its derived goal.
///
/// Enums are persisted as their raw values so the Domain enums stay free of
/// any SwiftData conformance.
@Model
final class UserProfileEntity {
    var id: UUID
    var age: Int
    var heightCm: Double
    var weightKg: Double

    /// `nil` when the user declined to say and no value was recorded.
    var biologicalSexRawValue: String?
    var activityLevelRawValue: String
    var goalRawValue: String
    var targetWeightKg: Double?

    var goalCalories: Double
    var goalProtein: Double
    var goalCarbohydrates: Double
    var goalFat: Double

    init(profile: UserProfile, goal: NutritionGoal) {
        self.id = profile.id
        self.age = profile.age
        self.heightCm = profile.heightCm
        self.weightKg = profile.weightKg
        self.biologicalSexRawValue = profile.biologicalSex?.rawValue
        self.activityLevelRawValue = profile.activityLevel.rawValue
        self.goalRawValue = profile.goal.rawValue
        self.targetWeightKg = profile.targetWeightKg
        self.goalCalories = goal.calories
        self.goalProtein = goal.protein
        self.goalCarbohydrates = goal.carbohydrates
        self.goalFat = goal.fat
    }
}

extension UserProfileEntity {
    var profile: UserProfile {
        UserProfile(
            id: id,
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            biologicalSex: biologicalSexRawValue.flatMap(BiologicalSex.init(rawValue:)),
            activityLevel: ActivityLevel(rawValue: activityLevelRawValue) ?? .sedentary,
            goal: WeightGoal(rawValue: goalRawValue) ?? .maintain,
            targetWeightKg: targetWeightKg
        )
    }

    var nutritionGoal: NutritionGoal {
        NutritionGoal(
            calories: goalCalories,
            protein: goalProtein,
            carbohydrates: goalCarbohydrates,
            fat: goalFat
        )
    }

    func apply(profile: UserProfile) {
        age = profile.age
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        biologicalSexRawValue = profile.biologicalSex?.rawValue
        activityLevelRawValue = profile.activityLevel.rawValue
        goalRawValue = profile.goal.rawValue
        targetWeightKg = profile.targetWeightKg
    }

    func apply(goal: NutritionGoal) {
        goalCalories = goal.calories
        goalProtein = goal.protein
        goalCarbohydrates = goal.carbohydrates
        goalFat = goal.fat
    }
}
