import Foundation

public protocol WeightRepository: Sendable {
    func log(_ entry: WeightEntry) async throws

    /// Entries in the half-open interval `[start, end)`, oldest first.
    func entries(from start: Date, to end: Date) async throws -> [WeightEntry]

    /// The most recent weighing, or `nil` before the first one.
    func latest() async throws -> WeightEntry?
}
