import SwiftUI

/// Sends the user to onboarding until a profile exists, then to the dashboard.
struct RootView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var hasProfile: Bool?

    var body: some View {
        Group {
            switch hasProfile {
            case .none:
                ProgressView()
            case .some(false):
                OnboardingView { hasProfile = true }
            case .some(true):
                DashboardView()
            }
        }
        .task {
            let stored = try? await container.user.load()
            hasProfile = stored != nil
        }
    }
}
