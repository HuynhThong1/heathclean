import Foundation

/// Reduces raw weighings to one point per week, for §6.12's weight card.
public struct GetWeightSeriesUseCase: Sendable {
    private let weightRepository: any WeightRepository
    private let calendar: Calendar

    public init(weightRepository: any WeightRepository, calendar: Calendar = .current) {
        self.weightRepository = weightRepository
        self.calendar = calendar
    }

    /// Weeks are counted back from the day of `endingOn` in 7-day blocks, not
    /// aligned to Monday: the newest block always ends today, so the last point
    /// is the user's latest weighing rather than a partial calendar week.
    public func execute(endingOn: Date, weeks: Int) async throws -> WeightSeries {
        guard weeks > 0 else { return WeightSeries(weekCount: 0, points: []) }

        let today = calendar.startOfDay(for: endingOn)
        guard
            let start = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: today),
            let end = calendar.date(byAdding: .day, value: 1, to: today)
        else {
            return WeightSeries(weekCount: weeks, points: [])
        }

        let entries = try await weightRepository.entries(from: start, to: end)

        var latestPerWeek: [Int: WeightEntry] = [:]
        for entry in entries {
            guard let index = weekIndex(of: entry.date, today: today, weeks: weeks) else {
                continue
            }
            if let existing = latestPerWeek[index], existing.date >= entry.date { continue }
            latestPerWeek[index] = entry
        }

        let points = latestPerWeek.keys.sorted().map { index in
            let entry = latestPerWeek[index]!
            return WeightPoint(weekIndex: index, date: entry.date, kilograms: entry.kilograms)
        }
        return WeightSeries(weekCount: weeks, points: points)
    }

    private func weekIndex(of date: Date, today: Date, weeks: Int) -> Int? {
        let day = calendar.startOfDay(for: date)
        guard let daysAgo = calendar.dateComponents([.day], from: day, to: today).day,
            daysAgo >= 0
        else { return nil }

        let index = weeks - 1 - daysAgo / 7
        return index >= 0 ? index : nil
    }
}
