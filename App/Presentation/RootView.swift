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
            // `try?` here would nest the optional and make "no profile yet"
            // indistinguishable from "profile found".
            do {
                hasProfile = try await container.user.load() != nil
            } catch {
                hasProfile = false
            }
        }
    }
}
