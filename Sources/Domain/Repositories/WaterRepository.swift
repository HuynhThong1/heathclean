import Foundation

public protocol WaterRepository: Sendable {
    func log(_ entry: WaterEntry) async throws

    /// Entries in the half-open interval `[start, end)`, oldest first.
    func entries(from start: Date, to end: Date) async throws -> [WaterEntry]

    /// Removes one entry. This is what makes a mis-tap undoable — a quick-add
    /// button that cannot be taken back is a button people stop trusting, and
    /// water is the one figure in the app logged by tapping rather than typing.
    func delete(id: UUID) async throws
}
