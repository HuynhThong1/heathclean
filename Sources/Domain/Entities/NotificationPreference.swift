import Foundation

/// The five notification switches of handoff §6.13, which are §19's triggers
/// with "target exceeded" folded into `targetReached`.
///
/// §19 lists four budget triggers — 70%, 90%, reached, exceeded — but the
/// design draws three switches, and reaching the target and passing it are one
/// event to the user rather than two. Splitting them would mean a switch that
/// only ever fires *after* another one already has.
public enum NotificationPreference: String, CaseIterable, Sendable {
    /// 70% of the day's budget used.
    case seventyPercent
    /// 90% — near the target.
    case nearTarget
    /// The target reached, or passed.
    case targetReached
    /// A nudge on a day with nothing logged.
    case mealReminder
    /// The day's figures, in the evening.
    case dailySummary

    /// §6.13's defaults. The reminder is the one that is off: it is the only
    /// notification the user did not cause by using the app.
    public var isOnByDefault: Bool {
        self != .mealReminder
    }
}

public struct NotificationPreferences: Sendable, Equatable {
    public var enabled: Set<NotificationPreference>

    public init(enabled: Set<NotificationPreference>) {
        self.enabled = enabled
    }

    public static var `default`: NotificationPreferences {
        NotificationPreferences(
            enabled: Set(NotificationPreference.allCases.filter(\.isOnByDefault))
        )
    }

    public func isOn(_ preference: NotificationPreference) -> Bool {
        enabled.contains(preference)
    }

    public mutating func set(_ preference: NotificationPreference, on: Bool) {
        if on {
            enabled.insert(preference)
        } else {
            enabled.remove(preference)
        }
    }
}
