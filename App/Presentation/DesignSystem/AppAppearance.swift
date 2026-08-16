import SwiftUI

/// Which appearance the app draws in, chosen on Profile.
///
/// Stored in `UserDefaults` rather than going through a repository: it is a
/// display preference with no bearing on any calculation, so it is not Domain
/// state and `UserProfile` has no business carrying it.
///
/// **The default is `.light`, deliberately.** The handoff and the FPT IS design
/// system behind it are light-only, so every dark value in `DesignTokens` was
/// derived in this repo rather than published. Following the system would hand
/// an unverified palette to anyone whose phone is set to dark; this way dark is
/// something the user asks for. Revisit when the brand team publishes real dark
/// values — at that point `.system` is the better default.
enum AppAppearance: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: L("Sáng")
        case .dark: L("Tối")
        case .system: L("Theo hệ thống")
        }
    }

    /// `nil` hands the decision back to iOS, which is what `.system` means.
    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
