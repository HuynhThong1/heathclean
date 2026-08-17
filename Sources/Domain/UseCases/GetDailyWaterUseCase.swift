import Foundation

/// The day's water, and the entries behind it.
///
/// It hands back the entries rather than only a total because the last one is
/// what "Hoàn tác" removes, and a total cannot be un-added.
public struct DailyWater: Sendable, Equatable {
    public let target: Double
    public let entries: [WaterEntry]

    public init(target: Double, entries: [WaterEntry]) {
        self.target = target
        self.entries = entries
    }

    public var consumed: Double { entries.reduce(0) { $0 + $1.millilitres } }

    /// Never negative: drinking past the target leaves nothing remaining rather
    /// than a debt. Unlike calories there is no "over" state to report — §0.3's
    /// rule that the app does not scold applies with more force to water, where
    /// exceeding a rule-of-thumb figure is not a finding at all.
    public var remaining: Double { max(0, target - consumed) }

    /// Clamped to 1 so the bar cannot run off its track.
    public var fraction: Double {
        target > 0 ? min(consumed / target, 1) : 0
    }

    /// What "Hoàn tác" takes back — the most recently *logged* drink, which is
    /// the one the user just tapped.
    public var mostRecent: WaterEntry? {
        entries.max { $0.date < $1.date }
    }
}

public struct GetDailyWaterUseCase: Sendable {
    private let waterRepository: any WaterRepository
    private let calendar: Calendar

    public init(waterRepository: any WaterRepository, calendar: Calendar = .current) {
        self.waterRepository = waterRepository
        self.calendar = calendar
    }

    /// The local day containing `date`, using the same day boundaries the rest
    /// of the app does — a 23:30 glass belongs to the day the user thinks it
    /// does.
    public func execute(on date: Date, target: Double) async throws -> DailyWater {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return DailyWater(target: target, entries: [])
        }
        let entries = try await waterRepository.entries(from: start, to: end)
        return DailyWater(target: target, entries: entries)
    }
}

/// Adds one drink.
///
/// Thin on purpose — there is no rule to apply, unlike `RecordWeightUseCase`,
/// which suppresses a weighing that did not move. Two glasses of the same size
/// a minute apart are two glasses, and de-duplicating them would lose real
/// data. It exists so the App layer talks to a use case rather than reaching
/// past the seam into a repository, the way every other write does.
public struct LogWaterUseCase: Sendable {
    private let waterRepository: any WaterRepository

    public init(waterRepository: any WaterRepository) {
        self.waterRepository = waterRepository
    }

    public func execute(millilitres: Double, on date: Date) async throws {
        guard millilitres > 0 else { return }
        try await waterRepository.log(WaterEntry(date: date, millilitres: millilitres))
    }

    public func undo(_ entry: WaterEntry) async throws {
        try await waterRepository.delete(id: entry.id)
    }
}
