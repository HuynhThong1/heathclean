import Foundation
import SwiftUI

@main
struct HeathFirstApp: App {
    /// UI tests pass `-uiTesting` so each run starts from an empty store and
    /// lands on onboarding.
    @State private var container = DependencyContainer(
        inMemory: ProcessInfo.processInfo.arguments.contains("-uiTesting")
    )

    init() {
        // Before anything reads the language — `@AppStorage` below resolves when
        // `body` first runs, which is after this.
        AppLanguage.applyLaunchOverrideIfNeeded()
        DSAppearance.apply()
    }

    /// Read here rather than deeper down because `preferredColorScheme` has to
    /// be applied above every sheet and full-screen cover to reach them all.
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .light

    /// Same reason as `appearance`, and the same placement: `\.locale` has to sit
    /// above every sheet for the strings inside one to follow the choice.
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .system

    /// BRAND_SPEC §3's splash, and the flag is what makes it **once per cold
    /// launch**. `App` is not rebuilt when the process is merely suspended and
    /// resumed, so this stays `false` for the rest of the session and a warm
    /// launch shows nothing — there is no `scenePhase` hook here on purpose.
    ///
    /// Off under `-uiTesting`, the same rule that keeps the notification
    /// coordinator out of the suite: 860ms of full-screen overlay in front of
    /// every one of 31 tests is time spent, and a test that has to wait out an
    /// animation to reach a button is a test about the animation.
    @State private var isShowingSplash =
        !ProcessInfo.processInfo.arguments.contains("-uiTesting")

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(container)
                    .environment(\.locale, language.resolved.locale)
                    .preferredColorScheme(appearance.colorScheme)
                    // The environment locale reaches `Text`, but not a string a
                    // model already built and stored — those resolve once, at
                    // load. Rebuilding the tree re-runs every `.task`, which is
                    // the only thing that makes them agree. Changing language is
                    // deliberate and rare; losing the navigation stack is the
                    // right price for a screen that is wholly in one language.
                    .id(language.resolved)

                if isShowingSplash {
                    // Over a root that is already mounted and already loading, so
                    // the overlay gates nothing.
                    SplashOverlay { isShowingSplash = false }
                        .zIndex(1)
                }
            }
        }
    }
}
