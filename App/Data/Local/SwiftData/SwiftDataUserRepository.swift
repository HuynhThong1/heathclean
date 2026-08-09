import Domain
import Foundation
import SwiftData

@ModelActor
actor SwiftDataUserRepository: UserRepository {
    func load() async throws -> (profile: UserProfile, goal: NutritionGoal)? {
        guard let entity = try storedEntity() else { return nil }
        return (entity.profile, entity.nutritionGoal)
    }

    func save(profile: UserProfile, goal: NutritionGoal) async throws {
        if let entity = try storedEntity() {
            entity.apply(profile: profile)
            entity.apply(goal: goal)
        } else {
            modelContext.insert(UserProfileEntity(profile: profile, goal: goal))
        }
        try modelContext.save()
    }

    /// There is only ever one profile row.
    private func storedEntity() throws -> UserProfileEntity? {
        var descriptor = FetchDescriptor<UserProfileEntity>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
