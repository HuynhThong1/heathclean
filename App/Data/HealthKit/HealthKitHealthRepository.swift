import Domain
import Foundation
import HealthKit

/// Reads the day's figures from HealthKit.
///
/// An actor because `HKHealthStore` is not `Sendable` and the repository
/// protocol is.
///
/// Every read is independently optional and failures are swallowed per type: a
/// user may share steps but not sleep, and HealthKit reports a declined read as
/// an empty result rather than an error. One unreadable type must never cost
/// the others — `plan.md` §14.
actor HealthKitHealthRepository: HealthRepository {
    private let store = HKHealthStore()

    /// Maps the app's own vocabulary onto HealthKit's. Nothing is written —
    /// nutrition write-back is a later phase.
    private static func objectTypes(for types: Set<HealthDataType>) -> Set<HKObjectType> {
        var result: Set<HKObjectType> = []
        for type in types {
            switch type {
            case .steps: result.insert(HKQuantityType(.stepCount))
            case .activeEnergy: result.insert(HKQuantityType(.activeEnergyBurned))
            case .sleep: result.insert(HKCategoryType(.sleepAnalysis))
            case .bodyMass: result.insert(HKQuantityType(.bodyMass))
            }
        }
        return result
    }

    nonisolated var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization(for types: Set<HealthDataType>) async throws {
        guard isAvailable else { throw HealthUnavailableReason.notSupportedOnThisDevice }
        guard !types.isEmpty else { return }
        try await store.requestAuthorization(toShare: [], read: Self.objectTypes(for: types))
    }

    func snapshot(on date: Date) async throws -> HealthSnapshot {
        guard isAvailable else { throw HealthUnavailableReason.notSupportedOnThisDevice }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(24 * 60 * 60)
        // `NSPredicate` is not Sendable, so each query builds its own from the
        // Sendable date bounds rather than sharing one across child tasks.
        async let steps = sum(.stepCount, unit: .count(), from: start, to: end)
        async let active = sum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        async let sleep = sleepDuration(from: start, to: end)
        async let weight = mostRecent(.bodyMass, unit: .gramUnit(with: .kilo))

        return await HealthSnapshot(
            date: start,
            steps: steps.map { Int($0.rounded()) },
            activeEnergyKcal: active,
            sleepDuration: sleep,
            weightKg: weight
        )
    }

    // MARK: Queries

    /// `nil` when the type is unreadable or the day has no samples — the two are
    /// indistinguishable through HealthKit, and both mean "nothing to show".
    private func sum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(identifier),
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                options: .cumulativeSum
            ) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func mostRecent(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKQuantityType(identifier),
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Total time actually asleep. `inBed` is excluded — it overlaps the asleep
    /// stages and would double count.
    private func sleepDuration(from start: Date, to end: Date) async -> TimeInterval? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: HKQuery.predicateForSamples(withStart: start, end: end),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]

                let total = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                continuation.resume(returning: total > 0 ? total : nil)
            }
            store.execute(query)
        }
    }
}
