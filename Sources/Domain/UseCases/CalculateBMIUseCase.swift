public struct CalculateBMIUseCase: Sendable {
    public init() {}

    public func execute(weightKg: Double, heightCm: Double) -> BMI {
        let heightM = heightCm / 100
        return BMI(value: weightKg / (heightM * heightM))
    }

    public func execute(profile: UserProfile) -> BMI {
        execute(weightKg: profile.weightKg, heightCm: profile.heightCm)
    }
}
