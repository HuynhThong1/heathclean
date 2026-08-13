import Domain
import Foundation
import SwiftData
import UIKit

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
    /// The bytes behind `MealPhoto`. Not a repository: Domain has no notion of a
    /// file, so this is App-only by design (§32.5).
    let photoStore: MealPhotoStore
    private var didSeedHistoryFixture = false
    private var didSweepOrphanPhotos = false

    /// `nonisolated` so it can be built in a stored-property initializer, and
    /// because nothing it touches is main-actor bound.
    nonisolated init(inMemory: Bool = false) {
        // `MealPhotoEntity` was added after the store shipped. It migrates
        // lightly: a new model, plus a to-many relationship that is empty for
        // every meal written before it, so nothing old needs converting.
        let schema = Schema([
            UserProfileEntity.self, MealEntity.self, FoodItemEntity.self, WeightEntryEntity.self,
            MealPhotoEntity.self,
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
        photoStore = MealPhotoStore()

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

    /// Built with the history calendar rather than `.current`: the month grid's
    /// day boundaries have to be the week strip's, and the dashboard's.
    var getMealHistoryMonths: GetMealHistoryMonthsUseCase {
        GetMealHistoryMonthsUseCase(
            mealRepository: mealRepository,
            calendar: HistoryCalendar.mondayFirst()
        )
    }

    var getWeightSeries: GetWeightSeriesUseCase {
        GetWeightSeriesUseCase(weightRepository: weightRepository)
    }

    var recordWeight: RecordWeightUseCase {
        RecordWeightUseCase(weightRepository: weightRepository)
    }

    var user: any UserRepository { userRepository }

    /// Deletes photo files no stored meal refers to any more (§32.4).
    ///
    /// Runs once per launch, and only after the store answered: a query that
    /// failed must not be read as "no meal has photos", which would delete the
    /// user's whole photo directory.
    func sweepOrphanPhotosIfNeeded() async {
        guard !didSweepOrphanPhotos else { return }
        didSweepOrphanPhotos = true
        guard let ids = try? await mealRepository.photoIDs() else { return }
        await photoStore.deleteOrphans(keeping: Set(ids))
    }

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
        // Written through the real `MealPhotoStore`, so the fixture exercises the
        // file path the scan uses — the picker and the camera cannot be driven
        // from a test, and a thumbnail is the one thing §32 stage 2 adds that has
        // to be seen to be believed.
        let photos = await fixturePhoto(capturedAt: date).map { [$0] } ?? []
        try? await saveMeal.execute(Meal(date: date, type: .lunch, items: [main, side], photos: photos))

        // Enough logged days that the list is longer than the screen. History is a
        // list of days now, so a two-day fixture cannot scroll — and a scroll
        // position test that never scrolls passes without testing anything.
        // Skips −7, which already has the meal above.
        for offset in [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13] {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else {
                continue
            }
            let snack = FoodItem(
                name: "Bữa nền \(offset)",
                weightGrams: 150,
                calories: 300,
                protein: 10,
                carbohydrates: 35,
                fat: 9
            )
            try? await saveMeal.execute(Meal(date: day, type: .snack, items: [snack]))
        }

        // A meal further back than the opening three-month window, which is what
        // gives `canLoadMore` something to be true about: without one, there is
        // nothing older to page to and the footer never appears (§32.3).
        if let older = calendar.date(byAdding: .day, value: -100, to: Date()) {
            let breakfast = FoodItem(
                name: "Bánh mì cũ",
                weightGrams: 180,
                calories: 320,
                protein: 12,
                carbohydrates: 40,
                fat: 11
            )
            try? await saveMeal.execute(
                Meal(date: older, type: .breakfast, items: [breakfast])
            )
        }
    }

    private func fixturePhoto(capturedAt: Date) async -> MealPhoto? {
        let size = CGSize(width: 600, height: 600)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.95, green: 0.44, blue: 0.13, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.99, green: 0.85, blue: 0.62, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 110, y: 110, width: 380, height: 380))
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        return try? await photoStore.save(data, capturedAt: capturedAt)
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
            saveMeal: saveMeal,
            photoStore: photoStore
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
            removeFoodItem: RemoveFoodItemUseCase(mealRepository: mealRepository),
            photoStore: photoStore
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

    func makeHistoryMonthsModel() -> HistoryMonthsModel {
        HistoryMonthsModel(
            getMonths: getMealHistoryMonths,
            mealRepository: mealRepository,
            userRepository: userRepository
        )
    }
}
