import SwiftUI

/// Runs the first-run flow from §5 — Welcome → Onboarding → Apple Health →
/// Dashboard — and goes straight to the dashboard once a profile exists.
struct RootView: View {
    @Environment(DependencyContainer.self) private var container

    @State private var hasProfile: Bool?
    @State private var stage: FirstRunStage = .welcome
    @State private var onboardingModel: OnboardingModel?

    private enum FirstRunStage {
        case welcome, onboarding, health
    }

    var body: some View {
        Group {
            switch hasProfile {
            case .none:
                ProgressView()
            case .some(true):
                MainTabView()
            case .some(false):
                firstRun
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

    @ViewBuilder
    private var firstRun: some View {
        switch stage {
        case .welcome:
            WelcomeView { stage = .onboarding }
        case .onboarding:
            OnboardingView(model: onboardingOrNew) { stage = .health }
        case .health:
            // Carries the same model, so the types chosen here belong to the
            // profile that was just filled in.
            HealthPermissionView(
                model: onboardingOrNew,
                onBack: { stage = .onboarding },
                onFinished: { hasProfile = true }
            )
        }
    }

    private var onboardingOrNew: OnboardingModel {
        if let onboardingModel { return onboardingModel }
        let model = container.makeOnboardingModel()
        Task { @MainActor in onboardingModel = model }
        return model
    }
}
