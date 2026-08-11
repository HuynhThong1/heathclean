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
        DSAppearance.apply()
    }

    /// Read here rather than deeper down because `preferredColorScheme` has to
    /// be applied above every sheet and full-screen cover to reach them all.
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .light

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
