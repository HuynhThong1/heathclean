import Domain
import Foundation
import Testing

@Suite("Weight series")
struct WeightSeriesTests {
    private func series(
        _ entries: [WeightEntry],
        weeks: Int = 6
    ) async throws -> WeightSeries {
        let useCase = GetWeightSeriesUseCase(
            weightRepository: InMemoryWeightRepository(stored: entries),
            calendar: testCalendar
        )
        return try await useCase.execute(endingOn: referenceDate, weeks: weeks)
    }

    @Test("one weighing a week becomes one point a week")
    func weeklyWeighings() async throws {
        // The design's series, weighed 35, 28, 21, 14, 7 and 0 days ago.
        let kilograms = [81.4, 80.6, 80.1, 79.4, 78.9, 78.5]
        let result = try await series(
            kilograms.enumerated().map { index, value in
                WeightEntry(date: daysBeforeReference(35 - index * 7), kilograms: value)
            }
        )

        #expect(result.points.map(\.weekIndex) == [0, 1, 2, 3, 4, 5])
        for (point, expected) in zip(result.points, kilograms) {
            expectClose(point.kilograms, expected)
        }
        expectClose(result.current ?? 0, 78.5)
        expectClose(result.change ?? 0, -2.9)
    }

    @Test("a week with several weighings keeps only the most recent")
    func latestWinsWithinAWeek() async throws {
        let result = try await series([
            WeightEntry(date: daysBeforeReference(6), kilograms: 80),
            WeightEntry(date: daysBeforeReference(4), kilograms: 79),
            WeightEntry(date: daysBeforeReference(1), kilograms: 78.2),
        ])

        #expect(result.points.count == 1)
        expectClose(result.points[0].kilograms, 78.2)
        #expect(result.points[0].weekIndex == 5)
    }

    @Test("a week without a weighing leaves a gap rather than a carried value")
    func missingWeekIsAGap() async throws {
        let result = try await series([
            WeightEntry(date: daysBeforeReference(35), kilograms: 81.4),
            // nothing 28 or 21 days ago
            WeightEntry(date: daysBeforeReference(14), kilograms: 79.4),
            WeightEntry(date: daysBeforeReference(0), kilograms: 78.5),
        ])

        #expect(result.points.map(\.weekIndex) == [0, 3, 5])
        #expect(result.weekCount == 6)
    }

    @Test("weighings older than the range are excluded")
    func olderThanRange() async throws {
        let result = try await series([
            WeightEntry(date: daysBeforeReference(42), kilograms: 85),
            WeightEntry(date: daysBeforeReference(41), kilograms: 84.6),
            WeightEntry(date: daysBeforeReference(3), kilograms: 78.5),
        ])

        // 41 days ago is the oldest day still in a six-week range; 42 is out.
        #expect(result.points.map(\.weekIndex) == [0, 5])
        expectClose(result.points[0].kilograms, 84.6)
    }

    @Test("a single weighing has a current value but no change")
    func singlePointHasNoChange() async throws {
        let result = try await series([
            WeightEntry(date: daysBeforeReference(2), kilograms: 78.5)
        ])

        expectClose(result.current ?? 0, 78.5)
        #expect(result.change == nil)
    }

    @Test("no weighings is an empty series, not an error")
    func empty() async throws {
        let result = try await series([])

        #expect(result.points.isEmpty)
        #expect(result.current == nil)
        #expect(result.change == nil)
        #expect(result.weekCount == 6)
    }
}
