import Foundation

public struct UserProfile: Sendable, Equatable, Identifiable {
    public let id: UUID

    public var age: Int
    public var heightCm: Double
    public var weightKg: Double

    public var biologicalSex: BiologicalSex?
    public var activityLevel: ActivityLevel

    public var goal: WeightGoal
    public var targetWeightKg: Double?

    public init(
        id: UUID = UUID(),
        age: Int,
        heightCm: Double,
        weightKg: Double,
        biologicalSex: BiologicalSex?,
        activityLevel: ActivityLevel,
        goal: WeightGoal,
        targetWeightKg: Double? = nil
    ) {
        self.id = id
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.biologicalSex = biologicalSex
        self.activityLevel = activityLevel
        self.goal = goal
        self.targetWeightKg = targetWeightKg
    }
}
