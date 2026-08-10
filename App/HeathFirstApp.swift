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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
        }
    }
}
