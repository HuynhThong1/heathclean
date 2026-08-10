import Foundation

/// A day's readings from the platform health store.
///
/// Every reading is optional and independently so. Health authorization is
/// granted per data type, and a denied *read* is indistinguishable from "no
/// data recorded" — the store simply returns nothing either way. The app must
/// keep working in both cases, so absence is normal rather than an error.
public struct HealthSnapshot: Sendable, Equatable {
    public let date: Date

    public var steps: Int?
    public var activeEnergyKcal: Double?
    public var basalEnergyKcal: Double?
    public var sleepDuration: TimeInterval?
    public var weightKg: Double?
    public var heightCm: Double?

    public init(
        date: Date,
        steps: Int? = nil,
        activeEnergyKcal: Double? = nil,
        basalEnergyKcal: Double? = nil,
        sleepDuration: TimeInterval? = nil,
        weightKg: Double? = nil,
        heightCm: Double? = nil
    ) {
        self.date = date
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.basalEnergyKcal = basalEnergyKcal
        self.sleepDuration = sleepDuration
        self.weightKg = weightKg
        self.heightCm = heightCm
    }

    /// Nothing was readable — either the user declined every type, or the day
    /// has no recorded data yet.
    public var isEmpty: Bool {
        steps == nil
            && activeEnergyKcal == nil
            && basalEnergyKcal == nil
            && sleepDuration == nil
            && weightKg == nil
            && heightCm == nil
    }

    /// Active plus basal. `nil` only when neither is readable — one present and
    /// the other missing still yields a usable figure rather than discarding it.
    public var totalEnergyBurnedKcal: Double? {
        switch (activeEnergyKcal, basalEnergyKcal) {
        case let (active?, basal?): active + basal
        case let (active?, nil): active
        case let (nil, basal?): basal
        case (nil, nil): nil
        }
    }
}
