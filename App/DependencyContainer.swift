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
    private let waterRepository: any WaterRepository
    private let healthRepository: any HealthRepository
    private let recognitionRepository: any FoodRecognitionRepository
    /// The bytes behind `MealPhoto`. Not a repository: Domain has no notion of a
    /// file, so this is App-only by design (§32.5).
    let photoStore: MealPhotoStore
    /// §19's local notifications. Kept rather than made on demand: it carries
    /// the system authorization state and the day's high-water mark, which every
    /// caller has to agree about.
    ///
    /// Built on first use rather than in `init`, because `@Observable` turns a
    /// `var` into a computed property and `init` here is `nonisolated` — a
    /// main-actor-isolated observable cannot be constructed from it.
    @ObservationIgnored private var notificationCoordinator: NotificationCoordinator?
    private var didSeedHistoryFixture = false
    private var didSweepOrphanPhotos = false

    /// `nonisolated` so it can be built in a stored-property initializer, and
    /// because nothing it touches is main-actor bound.
    nonisolated init(inMemory: Bool = false) {
        // Every addition made after the store shipped is lightweight: two new
        // models (`MealPhotoEntity`, `WaterEntryEntity`) and four new *optional*
        // attributes (`MealEntity.calorieGoalWhenLogged`,
        // `FoodItemEntity.aiEstimatedName`, `FoodItemEntity.fiber`, and the pair
        // `UserProfileEntity.goalFiber` / `goalWaterMillilitres`), so existing
        // rows read back as `nil`. None needs a `SchemaMigrationPlan`; if one
        // ever does, the `fatalError` below is how it will announce itself.
        //
        // The first three were opened against a store an earlier build wrote,
        // rather than assumed to be fine for being the plainest case SwiftData
        // handles. CLAUDE.md's meal-photos section has the procedure; the Phase 5
        // additions have not had it run against them yet.
        let schema = Schema([
            UserProfileEntity.self, MealEntity.self, FoodItemEntity.self, WeightEntryEntity.self,
            MealPhotoEntity.self, WaterEntryEntity.self,
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
        waterRepository = SwiftDataWaterRepository(modelContainer: modelContainer)
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

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTesting"), arguments.contains("-scanFailureFixture") {
            // The failure branch of the scan, which nothing else can reach: the
            // mock always succeeds and a real gateway cannot be made to fail on
            // demand. Double-guarded, like the history and scan-image fixtures.
            recognitionRepository = FailingFoodRecognitionRepository()
        } else if let raw = setting("GATEWAY_URL"), let url = URL(string: raw) {
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

    /// Takes the user repository as well as the meal one: every save stamps the
    /// meal with the day's calorie target (HISTORY_SPEC §8).
    var saveMeal: SaveMealUseCase {
        SaveMealUseCase(mealRepository: mealRepository, userRepository: userRepository)
    }

    /// Built with the history calendar rather than `.current`: the history list's
    /// day boundaries have to be the dashboard's.
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

    /// Built with the history calendar for the same reason
    /// `getMealHistoryMonths` and the notifications are: a 23:30 glass has to
    /// count towards the day the dashboard is showing, not a different one.
    var getDailyWater: GetDailyWaterUseCase {
        GetDailyWaterUseCase(
            waterRepository: waterRepository,
            calendar: HistoryCalendar.mondayFirst()
        )
    }

    var logWater: LogWaterUseCase {
        LogWaterUseCase(waterRepository: waterRepository)
    }

    var user: any UserRepository { userRepository }

    /// Built with the history calendar for the same reason
    /// `getMealHistoryMonths` is: a notification's idea of "today" has to be the
    /// dashboard's, or a 23:30 meal counts towards a different day than the one
    /// it was shown on.
    var notifications: NotificationCoordinator {
        if let notificationCoordinator { return notificationCoordinator }
        let calendar = HistoryCalendar.mondayFirst()
        let created = NotificationCoordinator(
            userRepository: userRepository,
            getDailySummary: getDailySummary,
            evaluateCalorieBudget: evaluateCalorieBudget,
            plan: PlanNotificationsUseCase(calendar: calendar),
            calendar: calendar,
            settings: NotificationSettings()
        )
        notificationCoordinator = created
        return created
    }

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
        // Stamped with a target of its own, and deliberately not the 2.378 kcal
        // onboarding derives: this is the one place §8's recorded goal makes the
        // round trip through SwiftData, so the day has to be able to disagree with
        // today for a test to tell the two apart. The fixture runs before
        // onboarding, so every other meal here is saved with no profile to read and
        // falls back to the current goal — which is the mixed store real data will
        // be, one day at a time.
        try? await saveMeal.execute(
            Meal(
                date: date,
                type: .lunch,
                items: [main, side],
                photos: photos,
                calorieGoalWhenLogged: 1_900
            )
        )

        // Enough logged days that the list is longer than the screen. History is a
        // list of days now, so a two-day fixture cannot scroll — and a scroll
        // position test that never scrolls passes without testing anything.
        // Skips −7, which already has the meal above.
        for offset in [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13] {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else {
                continue
            }
            // Two of these carry §22's scan record, so Insights has a correction
            // rate to draw: yesterday's was corrected, the day before's was
            // accepted as the model proposed it — 1 of 2, which is a figure a test
            // can tell apart from both 0% and 100%. Their name, weight and
            // calories are untouched, so nothing else in the fixture moves.
            let scanRecord: (name: String, weight: Double)? =
                switch offset {
                case 1: ("Phở bò", 120)  // renamed *and* re-weighed
                case 2: ("Bữa nền 2", 150)  // taken as offered
                default: nil
                }
            let snack = FoodItem(
                name: "Bữa nền \(offset)",
                weightGrams: 150,
                calories: 300,
                protein: 10,
                carbohydrates: 35,
                fat: 9,
                aiConfidence: scanRecord == nil ? nil : 0.92,
                aiEstimatedWeightGrams: scanRecord?.weight,
                aiEstimatedName: scanRecord?.name
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
            calculateBMI: calculateBMI,
            getDailyWater: getDailyWater,
            logWater: logWater,
            notifications: notifications
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

    /// The writer it is handed is an `OnboardingModel`, which is not a leftover:
    /// `OnboardingModel.save()` is the single place a profile and a weighing are
    /// written together, and `EditProfileModel` hands its draft to it rather
    /// than becoming a second writer that can forget the weighing.
    func makeEditProfileModel() -> EditProfileModel {
        EditProfileModel(
            writer: makeOnboardingModel(),
            userRepository: userRepository,
            calculateCalorieGoal: calculateCalorieGoal
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

    func makeHistoryMonthsModel() -> HistoryMonthsModel {
        HistoryMonthsModel(
            getMonths: getMealHistoryMonths,
            mealRepository: mealRepository,
            userRepository: userRepository
        )
    }
}
