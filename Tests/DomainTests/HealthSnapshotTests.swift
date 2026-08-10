import Domain
import Foundation
import Testing

@Suite("Health snapshot")
struct HealthSnapshotTests {
    @Test("a snapshot with no readings is empty")
    func emptyWhenNothingRead() {
        #expect(HealthSnapshot(date: referenceDate).isEmpty)
    }

    @Test("a single reading is enough to be non-empty")
    func nonEmptyWithOneReading() {
        #expect(!HealthSnapshot(date: referenceDate, steps: 0).isEmpty)
    }

    @Test("energy burned sums active and basal")
    func totalEnergy() {
        let snapshot = HealthSnapshot(
            date: referenceDate,
            activeEnergyKcal: 425,
            basalEnergyKcal: 1680
        )
        expectClose(snapshot.totalEnergyBurnedKcal ?? 0, 2105)
    }

    @Test("energy burned keeps whichever half is readable")
    func totalEnergyWithOneHalfMissing() {
        let activeOnly = HealthSnapshot(date: referenceDate, activeEnergyKcal: 425)
        let basalOnly = HealthSnapshot(date: referenceDate, basalEnergyKcal: 1680)
        expectClose(activeOnly.totalEnergyBurnedKcal ?? 0, 425, "active only")
        expectClose(basalOnly.totalEnergyBurnedKcal ?? 0, 1680, "basal only")
    }

    @Test("energy burned is nil only when neither half is readable")
    func totalEnergyMissing() {
        #expect(HealthSnapshot(date: referenceDate, steps: 900).totalEnergyBurnedKcal == nil)
    }
}
