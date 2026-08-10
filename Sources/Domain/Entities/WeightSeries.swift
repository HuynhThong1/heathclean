import Foundation

/// One plotted point: the most recent weighing within its week.
public struct WeightPoint: Sendable, Equatable {
    /// 0 is the oldest week in the range, `weekCount - 1` the week containing
    /// the reference date. The chart needs the index rather than a position in
    /// the array because a week with no weighing produces no point at all.
    public let weekIndex: Int
    public let date: Date
    public let kilograms: Double

    public init(weekIndex: Int, date: Date, kilograms: Double) {
        self.weekIndex = weekIndex
        self.date = date
        self.kilograms = kilograms
    }
}

public struct WeightSeries: Sendable, Equatable {
    public let weekCount: Int

    /// Ascending by `weekIndex`. Shorter than `weekCount` when weeks were
    /// skipped — gaps are left as gaps rather than carried forward, because a
    /// weight that was never measured is not a measurement.
    public let points: [WeightPoint]

    public init(weekCount: Int, points: [WeightPoint]) {
        self.weekCount = weekCount
        self.points = points
    }

    public var current: Double? { points.last?.kilograms }

    /// Net change across the range. `nil` with fewer than two points, where
    /// there is nothing to compare against.
    public var change: Double? {
        guard let first = points.first, let last = points.last, points.count >= 2 else {
            return nil
        }
        return last.kilograms - first.kilograms
    }
}
