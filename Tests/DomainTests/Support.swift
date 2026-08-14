import Domain
import Foundation
import Testing

/// Floating point comparison. Kept under its own name so a `Double` is never
/// compared with `==` by accident.
func expectClose(
    _ actual: Double,
    _ expected: Double,
    _ comment: Comment? = nil,
    tolerance: Double = 0.01,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        abs(actual - expected) <= tolerance,
        comment ?? "expected \(expected), got \(actual)",
        sourceLocation: sourceLocation
    )
}

/// Reference profile: male, 80 kg, 180 cm, 30 years old.
/// Mifflin-St Jeor BMR = 10·80 + 6.25·180 − 5·30 + 5 = 1780 kcal.
func makeProfile(
    age: Int = 30,
    heightCm: Double = 180,
    weightKg: Double = 80,
    biologicalSex: BiologicalSex? = .male,
    activityLevel: ActivityLevel = .moderate,
    goal: WeightGoal = .maintain
) -> UserProfile {
    UserProfile(
        age: age,
        heightCm: heightCm,
        weightKg: weightKg,
        biologicalSex: biologicalSex,
        activityLevel: activityLevel,
        goal: goal
    )
}

func makeFoodItem(
    name: String = "White rice",
    weightGrams: Double = 180,
    calories: Double = 234,
    protein: Double = 4.3,
    carbohydrates: Double = 50,
    fat: Double = 0.4
) -> FoodItem {
    FoodItem(
        name: name,
        weightGrams: weightGrams,
        calories: calories,
        protein: protein,
        carbohydrates: carbohydrates,
        fat: fat
    )
}

/// A fixed instant so tests never depend on the wall clock.
let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

/// A calendar fixed to UTC so day boundaries do not move with the machine's
/// time zone — `referenceDate` is an absolute instant, and `startOfDay` for it
/// is a different day in Hanoi than in Los Angeles.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// `days` before `referenceDate`, at the same time of day.
func daysBeforeReference(_ days: Int) -> Date {
    referenceDate.addingTimeInterval(Double(-days) * 86_400)
}

actor InMemoryWeightRepository: WeightRepository {
    private var stored: [WeightEntry]

    init(stored: [WeightEntry] = []) {
        self.stored = stored
    }

    func log(_ entry: WeightEntry) async throws {
        stored.append(entry)
    }

    func entries(from start: Date, to end: Date) async throws -> [WeightEntry] {
        stored.filter { $0.date >= start && $0.date < end }.sorted { $0.date < $1.date }
    }

    func latest() async throws -> WeightEntry? {
        stored.max { $0.date < $1.date }
    }

    var count: Int { stored.count }
}

/// A profile store that can also be made to fail, because "the profile could not
/// be read" is a branch with its own behaviour: `SaveMealUseCase` still saves the
/// meal, unstamped.
actor InMemoryUserRepository: UserRepository {
    struct ReadFailure: Error {}

    private var stored: (profile: UserProfile, goal: NutritionGoal)?
    private let failsToLoad: Bool

    init(profile: UserProfile? = nil, goal: NutritionGoal? = nil, failsToLoad: Bool = false) {
        if let profile, let goal {
            stored = (profile, goal)
        }
        self.failsToLoad = failsToLoad
    }

    func load() async throws -> (profile: UserProfile, goal: NutritionGoal)? {
        if failsToLoad { throw ReadFailure() }
        return stored
    }

    func save(profile: UserProfile, goal: NutritionGoal) async throws {
        stored = (profile, goal)
    }
}

actor InMemoryMealRepository: MealRepository {
    private var stored: [Meal]

    init(stored: [Meal] = []) {
        self.stored = stored
    }

    var count: Int { stored.count }

    func save(_ meal: Meal) async throws {
        stored.append(meal)
    }

    func meals(on date: Date) async throws -> [Meal] {
        stored.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func meals(from start: Date, to end: Date) async throws -> [Meal] {
        stored.filter { $0.date >= start && $0.date < end }
    }

    func earliestMealDate() async throws -> Date? {
        stored.min { $0.date < $1.date }?.date
    }

    func update(_ meal: Meal) async throws {
        guard let index = stored.firstIndex(where: { $0.id == meal.id }) else { return }
        stored[index] = meal
    }

    @discardableResult
    func delete(mealID: UUID) async throws -> [UUID] {
        let removed = stored.filter { $0.id == mealID }.flatMap(\.photos).map(\.id)
        stored.removeAll { $0.id == mealID }
        return removed
    }

    func photoIDs() async throws -> [UUID] {
        stored.flatMap(\.photos).map(\.id)
    }

    func all() -> [Meal] { stored }
}
