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
    private var didSeedHistoryFixture = false

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

        // The environment remains the development override. Device builds can
        // additionally inject GATEWAY_URL into Info.plist so launching later
        // from the Home Screen does not silently fall back to the mock.
        //
        // Either way the key is *present* in Info.plist and only its value says
        // whether it was configured, so absence has to be tested rather than
        // read off a nil. Measured on a Debug simulator build with neither
        // setting defined, `$(GATEWAY_URL)` expands to "" — so the empty check
        // is the one that actually fires. The "$(" check stays because that is
        // the other documented outcome when expansion does not run, and it has
        // not been re-measured on a device build.
        func setting(_ name: String) -> String? {
            let raw = ProcessInfo.processInfo.environment[name]
                ?? Bundle.main.object(forInfoDictionaryKey: name) as? String
            guard let raw, !raw.isEmpty, !raw.hasPrefix("$(") else { return nil }
            return raw
        }

        if let raw = setting("GATEWAY_URL"), let url = URL(string: raw) {
            recognitionRepository = GatewayFoodRecognitionRepository(
                baseURL: url,
                providerOverride: ProcessInfo.processInfo.environment["MODEL_PROVIDER"],
                apiKey: setting("GATEWAY_API_KEY")
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

    /// Gives the calendar UI test a real meal on the same weekday one week ago.
    /// The double launch-argument guard keeps this path unreachable in normal
    /// builds while still exercising the production SwiftData repository.
    func seedUITestHistoryFixtureIfNeeded() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard !didSeedHistoryFixture,
              arguments.contains("-uiTesting"),
              arguments.contains("-seedHistoryFixture") else { return }
        didSeedHistoryFixture = true

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        guard let date = calendar.date(byAdding: .day, value: -7, to: Date()) else { return }

        let main = FoodItem(
            name: "Cơm gà lịch sử",
            weightGrams: 260,
            calories: 400,
            protein: 30,
            carbohydrates: 48,
            fat: 12
        )
        let side = FoodItem(
            name: "Rau luộc",
            weightGrams: 140,
            calories: 210,
            protein: 2,
            carbohydrates: 20,
            fat: 7
        )
        try? await saveMeal.execute(Meal(date: date, type: .lunch, items: [main, side]))
    }

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
            mealRepository: mealRepository,
            removeFoodItem: RemoveFoodItemUseCase(mealRepository: mealRepository)
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
