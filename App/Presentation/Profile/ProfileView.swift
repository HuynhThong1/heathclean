import Domain
import SwiftUI

/// Profile — PROFILE_SPEC §1.
///
/// The screen is assembled from `SectionLabel` / `SettingsCard` / `SettingsRow`
/// and four blocks, each of which owns its own state: nothing here knows how a
/// notification is scheduled or which appearance is stored.
///
/// The stack runs at `spacing: 0` on purpose — §1's rhythm is asymmetric (22
/// above a section label, 10 below) and lives inside `SectionLabel`. A spacing
/// on the stack would add to it and quietly double every gap.
struct ProfileView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var model: ProfileModel?
    @State private var isEditingProfile = false
    @State private var isShowingHealth = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let model, let goal = model.goal {
                    ProfileHeaderCard(
                        goal: goal,
                        bodyLine: model.bodyLine,
                        bmi: model.bmi,
                        kilogramsToTarget: model.kilogramsToTarget,
                        onEdit: { isEditingProfile = true }
                    )
                    settingsSection(model)
                    displaySection
                    NotificationSection()
                    PrivacyCard()
                    ProfileFooter()
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(.horizontal, DS.s4)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(DS.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
        // Hiding the nav bar leaves nothing masking the top inset, so content
        // scrolled up through the clock. The strip needs a header with real
        // height — an empty one is 16pt of padding and nothing else, which is
        // how this broke once already.
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, DS.s4 + 4)
                .padding(.top, DS.s2)
                .padding(.bottom, DS.s3)
                .background(DS.surfacePage)
        }
        .task {
            if model == nil { model = container.makeProfileModel() }
            await model?.load()
        }
        .navigationDestination(isPresented: $isEditingProfile) {
            // Push, not a sheet (§5). The reload is what makes the header card
            // and the dashboard agree with what was just saved.
            EditProfileView { Task { await model?.load() } }
        }
        .sheet(isPresented: $isShowingHealth) {
            HealthConnectSheet { Task { await model?.load() } }
        }
    }

    /// The eyebrow every tab root opens with, and it is structural: a 29pt title
    /// four points under the clock has nothing between it and the status bar,
    /// and this is the element that was meant to sit there.
    private var header: some View {
        // §1 writes it "TÔI · PROFILE" because the design is bilingual. The
        // other three roots draw one word each and the catalog answers the
        // English — "TÔI" becomes "PROFILE" — which is what §4's language
        // switch replaced the pairs with.
        Text("TÔI")
            .hfStyle(HFType.eyebrow)
            .foregroundStyle(DS.textSubtle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Sections

    private func settingsSection(_ model: ProfileModel) -> some View {
        VStack(spacing: 0) {
            SectionLabel("THIẾT LẬP")
            SettingsCard {
                SettingsRow(
                    "Thông tin cơ thể & mục tiêu",
                    value: nil,
                    showsChevron: true,
                    identifier: "profile.editBody"
                ) { isEditingProfile = true }

                SettingsDivider()

                SettingsRow(
                    "Apple Health",
                    value: model.healthStatusText,
                    showsChevron: true,
                    identifier: "profile.health"
                ) { isShowingHealth = true }

                SettingsDivider()

                // §1 draws a chevron here too. There is no units screen and no
                // units setting: the app is metric and kcal throughout, and a
                // chevron that opens nothing is a broken control. The row stays
                // because the fact is worth stating; the chevron does not.
                SettingsRow("Đơn vị đo", value: "kg · cm · kcal")
            }
        }
    }

    private var displaySection: some View {
        VStack(spacing: 0) {
            SectionLabel("NGÔN NGỮ & GIAO DIỆN")
            DisplaySettingsCard {
                // A notification's words are chosen when it is scheduled, so one
                // already in the queue would fire in the language the user just
                // left.
                Task { await container.notifications.refresh() }
            }
        }
    }
}

// MARK: - Sheets

/// The permission screen on its own, for changing what Apple Health may read.
private struct HealthConnectSheet: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var model: OnboardingModel?
    let onFinished: () -> Void

    var body: some View {
        Group {
            if let model {
                HealthPermissionView(
                    model: model,
                    onBack: { dismiss() },
                    onFinished: {
                        onFinished()
                        dismiss()
                    }
                )
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil { model = container.makeOnboardingModel() }
        }
    }
}
