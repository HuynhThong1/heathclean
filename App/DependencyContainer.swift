import Domain
import Foundation
import SwiftData

/// Owns the SwiftData container and hands out use cases wired to concrete
/// repositories. Views and view models only ever see Domain types.
@MainActor
@Observable
final class DependencyContainer {
    let modelContainer: ModelContainer

    private let userRepository: any UserRepository
    private let mealRepository: any MealRepository
    private let healthRepository: any HealthRepository

    /// `nonisolated` so it can be built in a stored-property initializer, and
    /// because nothing it touches is main-actor bound.
    nonisolated init(inMemory: Bool = false) {
        let schema = Schema([UserProfileEntity.self, MealEntity.self, FoodItemEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Nothing sensible remains if local storage cannot open.
            fatalError("Could not create the model container: \(error)")
        }

        userRepository = SwiftDataUserRepository(modelContainer: modelContainer)
        mealRepository = SwiftDataMealRepository(modelContainer: modelContainer)
        healthRepository = HealthKitHealthRepository()
    }

    var calculateBMI: CalculateBMIUseCase { CalculateBMIUseCase() }
    var calculateCalorieGoal: CalculateCalorieGoalUseCase { CalculateCalorieGoalUseCase() }
    var evaluateCalorieBudget: EvaluateCalorieBudgetUseCase { EvaluateCalorieBudgetUseCase() }

    var getDailySummary: GetDailySummaryUseCase {
        GetDailySummaryUseCase(mealRepository: mealRepository)
    }

    var saveMeal: SaveMealUseCase {
        SaveMealUseCase(mealRepository: mealRepository)
    }

    var user: any UserRepository { userRepository }

    func makeOnboardingModel() -> OnboardingModel {
        OnboardingModel(
            userRepository: userRepository,
            healthRepository: healthRepository,
            calculateBMI: calculateBMI,
            calculateCalorieGoal: calculateCalorieGoal
        )
    }

    func makeDashboardModel() -> DashboardModel {
        DashboardModel(
            userRepository: userRepository,
            healthRepository: healthRepository,
            getDailySummary: getDailySummary,
            evaluateCalorieBudget: evaluateCalorieBudget,
            calculateBMI: calculateBMI
        )
    }

    func makeMealEntryModel(type: MealType, date: Date) -> MealEntryModel {
        MealEntryModel(type: type, date: date, saveMeal: saveMeal)
    }

    func makeMealHistoryModel() -> MealHistoryModel {
        MealHistoryModel(mealRepository: mealRepository)
    }
}
