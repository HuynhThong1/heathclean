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
    private let weightRepository: any WeightRepository
    private let healthRepository: any HealthRepository
    private let recognitionRepository: any FoodRecognitionRepository

    /// `nonisolated` so it can be built in a stored-property initializer, and
    /// because nothing it touches is main-actor bound.
    nonisolated init(inMemory: Bool = false) {
        let schema = Schema([
            UserProfileEntity.self, MealEntity.self, FoodItemEntity.self, WeightEntryEntity.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Nothing sensible remains if local storage cannot open.
            fatalError("Could not create the model container: \(error)")
        }

        userRepository = SwiftDataUserRepository(modelContainer: modelContainer)
        mealRepository = SwiftDataMealRepository(modelContainer: modelContainer)
        weightRepository = SwiftDataWeightRepository(modelContainer: modelContainer)
        healthRepository = HealthKitHealthRepository()

        // No gateway is running by default, and no model is configured, so the
        // mock is the honest default — a scan that always fails would teach
        // nothing. Point GATEWAY_URL at a running gateway to use the real one.
        if let raw = ProcessInfo.processInfo.environment["GATEWAY_URL"],
           let url = URL(string: raw) {
            recognitionRepository = GatewayFoodRecognitionRepository(
                baseURL: url,
                providerOverride: ProcessInfo.processInfo.environment["MODEL_PROVIDER"]
            )
        } else {
            recognitionRepository = MockFoodRecognitionRepository()
        }
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

    var getWeightSeries: GetWeightSeriesUseCase {
        GetWeightSeriesUseCase(weightRepository: weightRepository)
    }

    var recordWeight: RecordWeightUseCase {
        RecordWeightUseCase(weightRepository: weightRepository)
    }

    var user: any UserRepository { userRepository }

    func makeOnboardingModel() -> OnboardingModel {
        OnboardingModel(
            userRepository: userRepository,
            healthRepository: healthRepository,
            calculateBMI: calculateBMI,
            calculateCalorieGoal: calculateCalorieGoal,
            recordWeight: recordWeight
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

    func makeScanModel(type: MealType) -> ScanModel {
        ScanModel(
            type: type,
            recognitionRepository: recognitionRepository,
            saveMeal: saveMeal
        )
    }

    func makeProfileModel() -> ProfileModel {
        ProfileModel(
            userRepository: userRepository,
            healthRepository: healthRepository,
            calculateBMI: calculateBMI
        )
    }

    func makeMealDetailModel(
        type: MealType,
        meals: [Meal],
        dailyGoalCalories: Double
    ) -> MealDetailModel {
        MealDetailModel(
            type: type,
            meals: meals,
            dailyGoalCalories: dailyGoalCalories,
            mealRepository: mealRepository
        )
    }

    func makeInsightsModel() -> InsightsModel {
        InsightsModel(
            mealRepository: mealRepository,
            userRepository: userRepository,
            getWeightSeries: getWeightSeries
        )
    }

    func makeMealHistoryModel() -> MealHistoryModel {
        MealHistoryModel(mealRepository: mealRepository, userRepository: userRepository)
    }
}
