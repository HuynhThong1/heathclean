/// The health data the app can ask to read.
///
/// Exists so the permission screen can express *which* types to request — the
/// system sheet then lists exactly what the user was shown, and nothing more.
public enum HealthDataType: String, CaseIterable, Sendable {
    case steps
    case activeEnergy
    case sleep
    case bodyMass
}
