import Foundation

/// Appends to the weight history when the profile's weight is saved.
///
/// The profile is re-saved whenever *anything* on it is edited — activity
/// level, goal, target — so recording unconditionally would stack duplicate
/// points on the chart for weighings that never happened. A weight that has
/// not moved is not a new measurement.
public struct RecordWeightUseCase: Sendable {
    private let weightRepository: any WeightRepository

    public init(weightRepository: any WeightRepository) {
        self.weightRepository = weightRepository
    }

    @discardableResult
    public func execute(kilograms: Double, on date: Date) async throws -> Bool {
        // Tolerance rather than `==`: the value round-trips through a Double in
        // the form and in storage, and no scale resolves below a gram anyway.
        if let latest = try await weightRepository.latest(),
            abs(latest.kilograms - kilograms) < 0.001
        {
            return false
        }
        try await weightRepository.log(WeightEntry(date: date, kilograms: kilograms))
        return true
    }
}
