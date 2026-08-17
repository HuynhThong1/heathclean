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

    /// Optional because the row may predate them, and because a stored `0`
    /// would be read as a real target of nothing. `nutritionGoal` re-derives
    /// them instead — see there.
    var goalFiber: Double?
    var goalWaterMillilitres: Double?

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
        self.goalFiber = goal.fiber
        self.goalWaterMillilitres = goal.waterMillilitres
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

    /// The stored goal, with anything this row predates **re-derived from the
    /// profile beside it**.
    ///
    /// A row written before fibre and water existed cannot know either, and a
    /// zero would be read as a real target of nothing — the same rule as
    /// `MealEntity.calorieGoalWhenLogged`, where `nil` is not `0`. The way out
    /// is different, and simpler, because the goal is a **pure function of the
    /// profile**: it can just be recomputed from the profile this very row
    /// carries, which is where every stored goal came from in the first place.
    ///
    /// Only the missing halves are taken from the recomputation. The four
    /// stored figures win even where they disagree — they are what the user was
    /// shown, and silently re-deriving those would let a formula change rewrite
    /// history.
    var nutritionGoal: NutritionGoal {
        let derived = CalculateCalorieGoalUseCase().execute(profile: profile)
        return NutritionGoal(
            calories: goalCalories,
            protein: goalProtein,
            carbohydrates: goalCarbohydrates,
            fat: goalFat,
            fiber: goalFiber ?? derived.fiber,
            waterMillilitres: goalWaterMillilitres ?? derived.waterMillilitres
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
        goalFiber = goal.fiber
        goalWaterMillilitres = goal.waterMillilitres
    }
}
