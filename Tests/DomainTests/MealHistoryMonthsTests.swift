import Domain
import Foundation
import Testing

@Suite("Meal history months")
struct MealHistoryMonthsTests {
    // MARK: Fixtures

    /// Gregorian, Monday-first, fixed zone — the app's history calendar (§32.3).
    /// Built per test rather than shared so the zone can vary, which is what two
    /// of these tests are about.
    private func historyCalendar(
        firstWeekday: Int = 2,
        timeZone: String = "UTC"
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// A wall-clock instant in `calendar`'s zone. Explicit components rather
    /// than `referenceDate` arithmetic, because these tests are *about* month
    /// and year boundaries and a day offset says nothing about where they fall.
    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        in calendar: Calendar
    ) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return calendar.date(from: parts)!
    }

    private func meal(
        at date: Date,
        type: MealType = .lunch,
        calories: Double = 400,
        protein: Double = 20,
        carbohydrates: Double = 50,
        fat: Double = 10,
        photos: [MealPhoto] = []
    ) -> Meal {
        Meal(
            date: date,
            type: type,
            items: [
                makeFoodItem(
                    calories: calories,
                    protein: protein,
                    carbohydrates: carbohydrates,
                    fat: fat
                )
            ],
            photos: photos
        )
    }

    private func photo(at date: Date) -> MealPhoto {
        MealPhoto(capturedAt: date, pixelWidth: 1_600, pixelHeight: 1_200)
    }

    /// A month's day by its day-of-month. Lookups rather than array indices: the
    /// array now holds only the days that have meals, so an index says nothing
    /// about which day it is.
    private func day(_ dayOfMonth: Int, of month: HistoryMonth, in calendar: Calendar) -> HistoryDay? {
        month.days.first { calendar.component(.day, from: $0.date) == dayOfMonth }
    }

    /// Records every range it is asked for, so a test can assert that paging
    /// makes one query over a span and not one per day.
    private actor SpyMealRepository: MealRepository {
        private let stored: [Meal]
        private(set) var ranges: [(start: Date, end: Date)] = []

        init(stored: [Meal]) {
            self.stored = stored
        }

        func save(_ meal: Meal) async throws {}
        func update(_ meal: Meal) async throws {}
        func delete(mealID: UUID) async throws -> [UUID] { [] }
        func photoIDs() async throws -> [UUID] { stored.flatMap(\.photos).map(\.id) }

        func meals(on date: Date) async throws -> [Meal] { [] }

        func earliestMealDate() async throws -> Date? {
            stored.min { $0.date < $1.date }?.date
        }

        func meals(from start: Date, to end: Date) async throws -> [Meal] {
            ranges.append((start, end))
            return stored.filter { $0.date >= start && $0.date < end }
        }
    }

    private func months(
        _ stored: [Meal] = [],
        today: Date,
        monthOffset: Int = 0,
        count: Int = 3,
        calendar: Calendar
    ) async throws -> [HistoryMonth] {
        let useCase = GetMealHistoryMonthsUseCase(
            mealRepository: InMemoryMealRepository(stored: stored),
            calendar: calendar
        )
        return try await useCase.execute(today: today, monthOffset: monthOffset, count: count)
    }

    // MARK: Shape

    @Test("months come back newest first, and each holds only its logged days")
    func shape() async throws {
        let calendar = historyCalendar()
        let result = try await months(
            [
                meal(at: date(2026, 8, 13, in: calendar), calories: 500),
                meal(at: date(2026, 8, 1, in: calendar), calories: 300),
                meal(at: date(2026, 7, 20, in: calendar), calories: 200),
            ],
            today: date(2026, 8, 13, in: calendar),
            calendar: calendar
        )

        #expect(result.map(\.id) == ["2026-08", "2026-07", "2026-06"])
        // Newest day first, matching the order of the months themselves.
        #expect(result[0].days.map { calendar.component(.day, from: $0.date) } == [13, 1])
        #expect(result[1].days.count == 1)
        #expect(result[2].days.isEmpty, "June is empty but still returned — paging counts months")
        #expect(result[2].hasMeals == false)
        expectClose(result[0].calories, 800)
    }

    @Test("a day nothing was logged on is absent, not empty")
    func emptyDaysAreAbsent() async throws {
        let calendar = historyCalendar()
        let result = try await months(
            [meal(at: date(2026, 8, 5, in: calendar))],
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        // The month has 13 days so far and one of them was eaten on.
        #expect(result[0].days.count == 1)
        #expect(day(5, of: result[0], in: calendar) != nil)
        #expect(day(6, of: result[0], in: calendar) == nil)
        #expect(result[0].hasMeals)
    }

    @Test("paging back from January crosses into the previous year")
    func yearBoundary() async throws {
        let calendar = historyCalendar()
        let result = try await months(
            [
                meal(at: date(2025, 12, 31, hour: 20, minute: 0, in: calendar), calories: 700),
                meal(at: date(2025, 11, 1, in: calendar), calories: 100),
            ],
            today: date(2026, 1, 5, in: calendar),
            monthOffset: 1,
            count: 2,
            calendar: calendar
        )

        #expect(result.map(\.id) == ["2025-12", "2025-11"])
        // New Year's Eve belongs to December, not to the January the app is in.
        #expect(day(31, of: result[0], in: calendar) != nil)
        expectClose(result[0].calories, 700)
        #expect(day(1, of: result[1], in: calendar) != nil)
    }

    @Test("the last day of a month lands in that month, whatever its length")
    func monthLengths() async throws {
        let calendar = historyCalendar()
        // 28, 30 and 31 day months, plus a leap February.
        let result = try await months(
            [
                meal(at: date(2024, 2, 29, hour: 19, minute: 30, in: calendar), calories: 100),
                meal(at: date(2024, 3, 31, hour: 19, minute: 30, in: calendar), calories: 200),
                meal(at: date(2024, 4, 30, hour: 19, minute: 30, in: calendar), calories: 300),
            ],
            today: date(2024, 4, 30, in: calendar),
            monthOffset: 0,
            count: 3,
            calendar: calendar
        )

        #expect(result.map(\.id) == ["2024-04", "2024-03", "2024-02"])
        #expect(day(30, of: result[0], in: calendar) != nil)
        #expect(day(31, of: result[1], in: calendar) != nil)
        #expect(day(29, of: result[2], in: calendar) != nil, "2024 has a 29 February")
    }

    @Test("28 February is the end of a non-leap February")
    func nonLeapFebruary() async throws {
        let calendar = historyCalendar()
        let result = try await months(
            [meal(at: date(2023, 2, 28, hour: 21, minute: 0, in: calendar), calories: 400)],
            today: date(2023, 3, 10, in: calendar),
            monthOffset: 1,
            count: 1,
            calendar: calendar
        )

        #expect(result[0].id == "2023-02")
        #expect(day(28, of: result[0], in: calendar) != nil)
    }

    // MARK: Day boundaries

    @Test("a meal belongs to the local day it was eaten on, either side of midnight")
    func dayBoundaries() async throws {
        let calendar = historyCalendar(timeZone: "Asia/Ho_Chi_Minh")
        let result = try await months(
            [
                meal(at: date(2026, 8, 10, hour: 0, minute: 0, in: calendar), calories: 100),
                meal(at: date(2026, 8, 10, hour: 23, minute: 59, in: calendar), calories: 200),
                meal(at: date(2026, 8, 11, hour: 0, minute: 1, in: calendar), calories: 300),
            ],
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        let tenth = day(10, of: result[0], in: calendar)
        let eleventh = day(11, of: result[0], in: calendar)
        #expect(tenth?.date == calendar.startOfDay(for: date(2026, 8, 10, in: calendar)))
        expectClose(tenth?.calories ?? 0, 300, "midnight and 23:59 are the same day")
        expectClose(eleventh?.calories ?? 0, 300, "one minute later is the next day")
    }

    @Test("a day is 23 hours long when the clocks go forward")
    func daylightSaving() async throws {
        // 8 March 2026, America/Los_Angeles: 02:00 becomes 03:00. Adding 86,400
        // seconds a day at a time would drift the grouping by an hour from here on.
        let calendar = historyCalendar(timeZone: "America/Los_Angeles")
        let result = try await months(
            [
                meal(at: date(2026, 3, 8, hour: 1, minute: 30, in: calendar), calories: 100),
                meal(at: date(2026, 3, 8, hour: 23, minute: 30, in: calendar), calories: 200),
                meal(at: date(2026, 3, 31, hour: 12, minute: 0, in: calendar), calories: 400),
            ],
            today: date(2026, 3, 31, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        for logged in result[0].days {
            #expect(logged.date == calendar.startOfDay(for: logged.date), "every day is a start of day")
        }
        expectClose(day(8, of: result[0], in: calendar)?.calories ?? 0, 300, "both meals on the 8th")
        expectClose(
            day(31, of: result[0], in: calendar)?.calories ?? 0,
            400,
            "the last day of the month is still reachable"
        )
    }

    // MARK: Contents of a day

    @Test("meals within a day are ordered by time and their nutrition adds up")
    func dayContents() async throws {
        let calendar = historyCalendar()
        let result = try await months(
            [
                // Inserted out of order on purpose.
                meal(at: date(2026, 8, 5, hour: 19, minute: 0, in: calendar), type: .dinner, calories: 600),
                meal(at: date(2026, 8, 5, hour: 7, minute: 30, in: calendar), type: .breakfast, calories: 300),
                meal(at: date(2026, 8, 5, hour: 12, minute: 15, in: calendar), type: .lunch, calories: 500),
            ],
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        let fifth = try #require(day(5, of: result[0], in: calendar))
        #expect(fifth.meals.map(\.type) == [.breakfast, .lunch, .dinner])
        expectClose(fifth.calories, 1400)
        expectClose(fifth.protein, 60)
        expectClose(fifth.carbohydrates, 150)
        expectClose(fifth.fat, 30)
        #expect(fifth.meals(of: .lunch).count == 1)
    }

    @Test("a day totals what the dashboard totals for the same meals")
    func agreesWithTheDailySummary() async throws {
        let calendar = historyCalendar()
        let meals = [
            meal(at: date(2026, 8, 5, hour: 7, minute: 30, in: calendar), type: .breakfast, calories: 300),
            meal(at: date(2026, 8, 5, hour: 12, minute: 15, in: calendar), type: .lunch, calories: 500),
        ]
        let result = try await months(
            meals,
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        // §32.9: history's figures have to be the dashboard's figures.
        let summary = DailyNutritionSummary(
            date: date(2026, 8, 5, in: calendar),
            goal: NutritionGoal(calories: 2000, protein: 140, carbohydrates: 200, fat: 55),
            meals: meals
        )
        let fifth = try #require(day(5, of: result[0], in: calendar))
        expectClose(fifth.calories, summary.consumedCalories)
        expectClose(fifth.protein, summary.consumedProtein)
        expectClose(fifth.carbohydrates, summary.consumedCarbohydrates)
        expectClose(fifth.fat, summary.consumedFat)
    }

    // MARK: Photos (§32 stage 2)

    @Test("the day's picture is the newest meal that has one, and that meal's first photo")
    func representativePhoto() async throws {
        let calendar = historyCalendar()
        let morning = photo(at: date(2026, 8, 5, hour: 7, minute: 30, in: calendar))
        let eveningFirst = photo(at: date(2026, 8, 5, hour: 19, minute: 0, in: calendar))
        let eveningSecond = photo(at: date(2026, 8, 5, hour: 19, minute: 2, in: calendar))

        let result = try await months(
            [
                meal(
                    at: date(2026, 8, 5, hour: 7, minute: 30, in: calendar),
                    type: .breakfast,
                    photos: [morning]
                ),
                meal(at: date(2026, 8, 5, hour: 12, minute: 15, in: calendar), type: .lunch),
                meal(
                    at: date(2026, 8, 5, hour: 19, minute: 0, in: calendar),
                    type: .dinner,
                    photos: [eveningFirst, eveningSecond]
                ),
            ],
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        let fifth = try #require(day(5, of: result[0], in: calendar))
        #expect(fifth.representativePhotoID == eveningFirst.id)
        #expect(fifth.photoCount == 3)
        #expect(fifth.photos.map(\.id) == [morning.id, eveningFirst.id, eveningSecond.id])
    }

    @Test("a day whose newest meal has no photo falls back to the newest one that does")
    func representativePhotoFallsBack() async throws {
        let calendar = historyCalendar()
        let morning = photo(at: date(2026, 8, 5, hour: 7, minute: 30, in: calendar))

        let result = try await months(
            [
                meal(
                    at: date(2026, 8, 5, hour: 7, minute: 30, in: calendar),
                    type: .breakfast,
                    photos: [morning]
                ),
                // Typed in by hand later in the day, so it has no picture. Taking
                // the newest meal outright would leave the row blank.
                meal(at: date(2026, 8, 5, hour: 19, minute: 0, in: calendar), type: .dinner),
            ],
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        #expect(day(5, of: result[0], in: calendar)?.representativePhotoID == morning.id)
    }

    @Test("a day with no photo has none, and says so rather than guessing")
    func noRepresentativePhoto() async throws {
        let calendar = historyCalendar()
        let result = try await months(
            [meal(at: date(2026, 8, 5, hour: 12, minute: 0, in: calendar))],
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        let fifth = try #require(day(5, of: result[0], in: calendar))
        #expect(fifth.representativePhotoID == nil)
        #expect(fifth.photoCount == 0)
        #expect(fifth.photos.isEmpty)
    }

    @Test("photos do not change what a day totals")
    func photosDoNotAffectTotals() async throws {
        let calendar = historyCalendar()
        let when = date(2026, 8, 5, hour: 12, minute: 0, in: calendar)
        let today = date(2026, 8, 13, in: calendar)

        let withPhoto = try await months(
            [meal(at: when, calories: 640, photos: [photo(at: when)])],
            today: today,
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )
        let without = try await months(
            [meal(at: when, calories: 640)],
            today: today,
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        expectClose(withPhoto[0].calories, without[0].calories)
        #expect(withPhoto[0].days.count == without[0].days.count)
    }

    // MARK: Querying

    @Test("the whole span is one query, ending with the last day shown")
    func oneQueryPerPage() async throws {
        let calendar = historyCalendar()
        let repository = SpyMealRepository(stored: [])
        let useCase = GetMealHistoryMonthsUseCase(mealRepository: repository, calendar: calendar)
        _ = try await useCase.execute(
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 3
        )

        let ranges = await repository.ranges
        #expect(ranges.count == 1, "three months, not ninety days")
        #expect(ranges[0].start == calendar.startOfDay(for: date(2026, 6, 1, in: calendar)))
        #expect(
            ranges[0].end == calendar.startOfDay(for: date(2026, 8, 14, in: calendar)),
            "exclusive end of today, so a meal dated tomorrow is not counted"
        )
    }

    @Test("a meal dated after today is not counted into the month")
    func futureMealsAreIgnored() async throws {
        let calendar = historyCalendar()
        let result = try await months(
            [
                meal(at: date(2026, 8, 13, hour: 12, minute: 0, in: calendar), calories: 400),
                meal(at: date(2026, 8, 20, hour: 12, minute: 0, in: calendar), calories: 900),
            ],
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 1,
            calendar: calendar
        )

        #expect(result[0].days.count == 1)
        expectClose(result[0].calories, 400)
    }

    @Test("asking for no months asks the store nothing")
    func degenerateRequests() async throws {
        let calendar = historyCalendar()
        let repository = SpyMealRepository(stored: [])
        let useCase = GetMealHistoryMonthsUseCase(mealRepository: repository, calendar: calendar)
        let today = date(2026, 8, 13, in: calendar)

        #expect(try await useCase.execute(today: today, monthOffset: 0, count: 0).isEmpty)
        #expect(try await useCase.execute(today: today, monthOffset: -1, count: 3).isEmpty)
        #expect(await repository.ranges.isEmpty)
    }

    @Test("paging asks for the months before the ones already loaded")
    func paging() async throws {
        let calendar = historyCalendar()
        let first = try await months(
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 0,
            count: 3,
            calendar: calendar
        )
        let second = try await months(
            today: date(2026, 8, 13, in: calendar),
            monthOffset: 3,
            count: 3,
            calendar: calendar
        )

        #expect(first.map(\.id) == ["2026-08", "2026-07", "2026-06"])
        #expect(second.map(\.id) == ["2026-05", "2026-04", "2026-03"])
        #expect(Set(first.map(\.id)).isDisjoint(with: second.map(\.id)), "no month arrives twice")
    }
}
