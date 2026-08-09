/// The profile and its derived goal always travel together — the goal is
/// recomputed whenever the profile changes — so they are stored as one unit.
public protocol UserRepository: Sendable {
    /// `nil` until onboarding completes.
    func load() async throws -> (profile: UserProfile, goal: NutritionGoal)?

    func save(profile: UserProfile, goal: NutritionGoal) async throws
}
