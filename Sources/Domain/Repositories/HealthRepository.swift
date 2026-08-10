import Foundation

public enum HealthUnavailableReason: Error, Equatable, Sendable {
    /// The device has no health store — iPad and Mac, for instance.
    case notSupportedOnThisDevice
}

/// Reads the platform health store.
///
/// Deliberately has no `authorizationStatus`: the platform does not report
/// whether a *read* was granted, precisely so an app cannot infer that a user
/// declined to share something. Callers should request authorization, then read,
/// and treat an empty `HealthSnapshot` as the normal "nothing to show" case.
public protocol HealthRepository: Sendable {
    /// `false` where no health store exists. Everything else will throw
    /// `HealthUnavailableReason.notSupportedOnThisDevice`.
    var isAvailable: Bool { get }

    /// Presents the system permission sheet the first time; subsequent calls
    /// return without prompting. Succeeding does **not** imply access was
    /// granted.
    ///
    /// `types` is what the user asked for on the permission screen — the sheet
    /// lists exactly these, so it can never show a type they were not shown.
    func requestAuthorization(for types: Set<HealthDataType>) async throws

    func snapshot(on date: Date) async throws -> HealthSnapshot
}
