import Domain
import Foundation

/// §6.13's five switches, in `UserDefaults`.
///
/// Stored the same way and for the same reason as `AppAppearance`: a preference
/// about how the app behaves on this device is not Domain state, and
/// `UserProfile` has no business carrying it. Unlike `AppAppearance` it cannot
/// be an `@AppStorage`, because `NotificationCoordinator` — which is not a view —
/// has to read it too.
@MainActor
@Observable
final class NotificationSettings {
    private let defaults: UserDefaults
    private(set) var preferences: NotificationPreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var loaded = NotificationPreferences(enabled: [])
        for preference in NotificationPreference.allCases {
            // `object(forKey:)`, not `bool(forKey:)`: an unset key reads back as
            // `false` there, which would silently turn four of the five switches
            // off on first launch — §6.13 has them on until the user says
            // otherwise.
            let stored = defaults.object(forKey: Self.key(for: preference)) as? Bool
            loaded.set(preference, on: stored ?? preference.isOnByDefault)
        }
        preferences = loaded
    }

    nonisolated static func key(for preference: NotificationPreference) -> String {
        "notification.\(preference.rawValue)"
    }

    func isOn(_ preference: NotificationPreference) -> Bool {
        preferences.isOn(preference)
    }

    func set(_ preference: NotificationPreference, on: Bool) {
        preferences.set(preference, on: on)
        defaults.set(on, forKey: Self.key(for: preference))
    }
}
