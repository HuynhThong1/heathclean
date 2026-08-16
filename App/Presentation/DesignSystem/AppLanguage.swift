import Foundation
import SwiftUI

/// Which language the app draws in, chosen on Profile.
///
/// Stored in `UserDefaults` for the reason `AppAppearance` is: it is a display
/// preference with no bearing on any calculation, so it is not Domain state and
/// `UserProfile` has no business carrying it.
///
/// **This replaces the handoff's §4 bilingual labels.** The design draws
/// Vietnamese on the primary line with English underneath, which is the right
/// answer when there is no way to choose — but once there is a switch, showing
/// both at once is showing the user a language they did not ask for. `HFLabel`
/// and `HFSectionHeader` therefore draw one line, in this language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case vietnamese = "vi"
    case english = "en"
    case system

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    /// The language actually drawn. `.system` is a preference, never a locale —
    /// everything downstream needs one of the two real answers.
    var resolved: ResolvedLanguage {
        switch self {
        case .vietnamese: .vietnamese
        case .english: .english
        case .system: .preferredBySystem
        }
    }
}

/// One of the two languages the app is actually built in.
///
/// Separate from `AppLanguage` so `.system` cannot reach a formatter or a bundle
/// lookup: a `Locale(identifier: "system")` fails silently and falls back to
/// something that looks almost right.
enum ResolvedLanguage: String, Hashable, CaseIterable {
    case vietnamese = "vi"
    case english = "en"

    /// What iOS would pick on its own, restricted to languages this app has.
    ///
    /// `Bundle.main.preferredLocalizations` rather than `Locale.current`: the
    /// latter answers with the *phone's* language even when the app carries no
    /// translation for it, so a Japanese phone would resolve to `.english` here
    /// only by accident of the `hasPrefix` check.
    static var preferredBySystem: ResolvedLanguage {
        let preferred = Bundle.main.preferredLocalizations.first ?? "vi"
        return preferred.hasPrefix("en") ? .english : .vietnamese
    }

    /// Numbers and dates follow the language, not the phone: "2.378 kcal" read
    /// on an English screen is two point three seven eight.
    var locale: Locale {
        switch self {
        case .vietnamese: Locale(identifier: "vi_VN")
        case .english: Locale(identifier: "en_US")
        }
    }

    /// The `.lproj` the string catalog compiled into. This — not `locale` — is
    /// what decides which language a lookup answers in.
    ///
    /// **Both `.lproj`s have to exist for this to be safe**, which is why every
    /// key in the catalog carries an explicit `vi` value equal to itself. Without
    /// them Xcode emits no `vi.lproj` — Vietnamese is the development language and
    /// a key *is* its own Vietnamese — and this falls through to `.main`, which
    /// then answers in whatever the **phone** is set to. On an English simulator
    /// that made `L()` return English while `Text` still returned Vietnamese:
    /// exactly half a screen in the wrong language, and a UI test found it.
    ///
    /// `Bundle(path:)` returns the instance already created for a path, so this
    /// is a dictionary lookup after the first call rather than a directory scan.
    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}

/// Resolve a string outside a SwiftUI view.
///
/// **`String(localized:)` does not read SwiftUI's `\.locale`.** It asks
/// `Bundle.main.preferredLocalizations`, which is the *phone's* language — so a
/// model that builds its own copy would ignore the switch on Profile and leave
/// half a screen in the other language. Every string built outside a `View` goes
/// through here; `Text("…")` inside a view does not need it, because the
/// environment locale set at the app root already covers it.
///
/// The literal stays a `String.LocalizationValue`, so `xcstringstool` still
/// extracts it into the catalog exactly as `String(localized:)` did.
func L(_ value: String.LocalizationValue) -> String {
    let language = AppLanguage.current.resolved
    return String(localized: value, bundle: language.bundle, locale: language.locale)
}

extension AppLanguage {
    /// The stored choice, read without `@AppStorage` — models, the notification
    /// coordinator and `L()` are not views and cannot use the property wrapper.
    ///
    /// Defaults to `.system`, matching the `@AppStorage` declarations, so the
    /// two readers can never disagree about an unset value.
    static var current: AppLanguage {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let stored = AppLanguage(rawValue: raw)
        else { return .system }
        return stored
    }

    /// Pins the language for a test run, before any view or model reads it.
    ///
    /// The default is `.system` and the simulator runs in English, so without
    /// this every UI test asserting Vietnamese copy would fail for a reason
    /// having nothing to do with the code. `-appLanguage <code>` overrides it,
    /// which is how the English path gets a test of its own.
    ///
    /// It writes into `UserDefaults` rather than being consulted separately, so
    /// `@AppStorage` and `current` see one value — a second source of truth for
    /// the language is exactly the bug this feature is most likely to have.
    ///
    /// Guarded on `-uiTesting` as well as its own argument, the same double
    /// guard that keeps `-seedHistoryFixture` unreachable in a real build.
    static func applyLaunchOverrideIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting") else { return }

        var override = AppLanguage.vietnamese
        if let index = arguments.firstIndex(of: "-appLanguage"),
           arguments.indices.contains(index + 1),
           let requested = AppLanguage(rawValue: arguments[index + 1]) {
            override = requested
        }
        UserDefaults.standard.set(override.rawValue, forKey: storageKey)
    }

    /// The picker's options.
    ///
    /// **A language names itself in its own language** — "Tiếng Việt" stays
    /// "Tiếng Việt" on an English screen, the way iOS Settings writes it, so a
    /// user who cannot read the current UI can still find their language. Hence
    /// `verbatim` for the two of them: they are not copy to translate, and
    /// putting them through the catalog would invite exactly that. Only "theo hệ
    /// thống" is a phrase.
    var label: Text {
        switch self {
        case .vietnamese: Text(verbatim: "Tiếng Việt")
        case .english: Text(verbatim: "English")
        case .system: Text("Theo hệ thống")
        }
    }
}
