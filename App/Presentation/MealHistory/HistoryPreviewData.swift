#if DEBUG
    import Domain
    import Foundation

    /// Fixtures for the history previews (HISTORY_SPEC §9 asks each piece for its
    /// own).
    ///
    /// `DEBUG` only, and Presentation-only: nothing here is a test fixture — the UI
    /// suite seeds through the real store with `-seedHistoryFixture`, because a
    /// preview may lie about what SwiftData does and a test may not.
    ///
    /// The photo ids are real `MealPhoto` values with no bytes behind them, which is
    /// the state a restored backup leaves too: chips fall back to their monogram and
    /// the panel's tiles to their placeholder. It is worth seeing that in a preview.
    enum HistoryPreviewData {
        // MARK: Days

        static let today = day(
            daysAgo: 0,
            meals: [
                meal(at: 6, 50, type: .breakfast, items: [("Phở gà", 430)], photos: 1),
                meal(
                    at: 12,
                    20,
                    type: .lunch,
                    items: [("Cơm gà xối mỡ", 520), ("Canh chua", 120), ("Sữa chua", 80)]
                ),
            ]
        )

        static let dayWithOnePhoto = day(
            daysAgo: 2,
            meals: [
                meal(at: 6, 50, type: .breakfast, items: [("Phở bò", 480)], photos: 1),
                meal(at: 12, 20, type: .lunch, items: [("Cơm gà", 720)]),
                meal(at: 15, 40, type: .snack, items: [("Sữa chua", 180)]),
            ]
        )

        /// Four meals, so the row also shows §4's "+1 món".
        static let dayWithSeveralPhotos = day(
            daysAgo: 4,
            meals: [
                meal(at: 7, 15, type: .breakfast, items: [("Xôi xéo", 520)], photos: 1),
                meal(at: 12, 10, type: .lunch, items: [("Bún chả", 890)], photos: 1),
                meal(at: 15, 30, type: .snack, items: [("Chè bưởi", 200)], photos: 1),
                meal(at: 19, 30, type: .dinner, items: [("Cá kho", 290)]),
            ]
        )

        static let dayWithoutPhotos = day(
            daysAgo: 6,
            meals: [
                meal(at: 8, 0, type: .breakfast, items: [("Bánh mì trứng", 420)]),
                meal(at: 12, 45, type: .lunch, items: [("Cơm tấm", 780)]),
            ]
        )

        static let dayOverBudget = day(
            daysAgo: 8,
            meals: [
                meal(at: 12, 10, type: .lunch, items: [("Bún bò Huế", 950)], photos: 1),
                meal(at: 19, 30, type: .dinner, items: [("Lẩu thái", 1_130)]),
            ]
        )

        static let goalCalories: Double = 1_900

        static let goal = NutritionGoal(
            calories: goalCalories,
            protein: 124,
            carbohydrates: 190,
            fat: 53
        )

        // MARK: Months

        /// The month those five days sit in, newest first — which is the order a
        /// `HistoryMonth` promises.
        static var month: HistoryMonth {
            let days = [
                today, dayWithOnePhoto, dayWithSeveralPhotos, dayWithoutPhotos, dayOverBudget,
            ]
            let parts = calendar.dateComponents([.year, .month], from: today.date)
            return HistoryMonth(
                year: parts.year ?? 0,
                month: parts.month ?? 0,
                // Days from a fortnight back can fall in the previous month; the
                // preview only needs them in one section.
                days: days.sorted { $0.date > $1.date }
            )
        }

        /// The month before it, with nothing logged — §6's divider case.
        static var emptyMonth: HistoryMonth {
            let start = calendar.date(byAdding: .month, value: -1, to: today.date) ?? today.date
            let parts = calendar.dateComponents([.year, .month], from: start)
            return HistoryMonth(year: parts.year ?? 0, month: parts.month ?? 0, days: [])
        }

        // MARK: Building blocks

        static let calendar = HistoryCalendar.mondayFirst()

        static func day(daysAgo: Int, meals: [(hour: Int, minute: Int, meal: Meal)]) -> HistoryDay {
            let start = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            )
            let dated = meals.map { entry in
                var meal = entry.meal
                meal.date =
                    calendar.date(
                        bySettingHour: entry.hour,
                        minute: entry.minute,
                        second: 0,
                        of: start
                    ) ?? start
                return meal
            }
            return HistoryDay(date: start, meals: dated.sorted { $0.date < $1.date })
        }

        /// The time is carried beside the meal because the day it belongs to is not
        /// known until `day(daysAgo:meals:)` places it.
        static func meal(
            at hour: Int,
            _ minute: Int,
            type: MealType,
            items: [(String, Double)],
            photos: Int = 0
        ) -> (hour: Int, minute: Int, meal: Meal) {
            let foods = items.map { name, calories in
                FoodItem(
                    name: name,
                    weightGrams: 300,
                    calories: calories,
                    // Split 20/50/30 by energy — plausible figures so the panel's
                    // macro bars have something to draw.
                    protein: calories * 0.20 / 4,
                    carbohydrates: calories * 0.50 / 4,
                    fat: calories * 0.30 / 9
                )
            }
            let pictures = (0..<photos).map { _ in
                MealPhoto(capturedAt: Date(), pixelWidth: 1_600, pixelHeight: 1_200)
            }
            return (
                hour, minute,
                Meal(date: Date(), type: type, items: foods, photos: pictures)
            )
        }
    }
#endif
