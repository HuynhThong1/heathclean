import Domain
import SwiftUI

/// Profile — handoff §6.13.
struct ProfileView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var model: ProfileModel?
    @State private var isEditingProfile = false
    @State private var isShowingHealth = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s5) {
                header

                if let model, let profile = model.profile, let goal = model.goal {
                    identityRow(model: model)
                    statCards(model: model, profile: profile, goal: goal)
                    settingsSection(model: model)
                    privacySection
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, DS.s2)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(DS.surfacePage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if model == nil { model = container.makeProfileModel() }
            await model?.load()
        }
        .sheet(isPresented: $isEditingProfile) {
            ProfileEditSheet {
                Task { await model?.load() }
            }
        }
        .sheet(isPresented: $isShowingHealth) {
            HealthConnectSheet {
                Task { await model?.load() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.s1) {
            Text("TÔI · PROFILE")
                .hfStyle(HFType.eyebrow)
                .foregroundStyle(DS.textSubtle)
        }
    }

    // MARK: Identity

    private func identityRow(model: ProfileModel) -> some View {
        HStack(spacing: DS.s4) {
            // §6.13 draws initials here, but nothing in the app ever asks for a
            // name — onboarding collects body data only. A generic glyph is
            // honest; invented initials would not be.
            Image(systemName: "person.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DS.blue700)
                .frame(width: 60, height: 60)
                .background(DS.blue100, in: Circle())

            VStack(alignment: .leading, spacing: DS.s1) {
                Text("Hồ sơ của bạn")
                    .font(.custom(DSFontName.bold, size: 19))
                    .foregroundStyle(DS.textStrong)
                if let line = model.bodyLine {
                    Text(line)
                        .font(.custom(DSFontName.regular, size: 12.5))
                        .foregroundStyle(DS.textMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hồ sơ của bạn, \(model.bodyLine ?? "")")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: Stats

    private func statCards(
        model: ProfileModel,
        profile: UserProfile,
        goal: NutritionGoal
    ) -> some View {
        HStack(spacing: DS.s2) {
            statCard(
                value: VNNumber.int(goal.calories),
                unit: "kcal",
                vi: "Mỗi ngày",
                background: DS.blue50,
                foreground: DS.blue700
            )
            statCard(
                value: model.bmi.map { VNNumber.oneDecimal($0.value) } ?? "—",
                unit: model.bmi?.category.vi ?? "",
                vi: "BMI",
                background: DS.surfaceSunken,
                foreground: DS.textStrong
            )
            statCard(
                value: model.kilogramsToTarget.map { VNNumber.oneDecimal($0) } ?? "—",
                unit: "kg",
                vi: model.kilogramsToTarget == nil ? "Không đặt" : "Còn lại",
                background: DS.green100,
                foreground: DS.green700
            )
        }
    }

    private func statCard(
        value: String,
        unit: String,
        vi: String,
        background: Color,
        foreground: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.custom(DSFontName.extrabold, size: 21))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(unit)
                .hfStyle(HFType.subLabelSemibold)
                .foregroundStyle(foreground.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(vi)
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.s3)
        .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vi), \(value) \(unit)")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: Settings

    private func settingsSection(model: ProfileModel) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            Text("THIẾT LẬP")
                .hfStyle(HFType.eyebrow)
                .foregroundStyle(DS.textSubtle)

            HFCard(padding: 0) {
                VStack(spacing: 0) {
                    settingsRow(
                        vi: "Thông tin cơ thể & mục tiêu",
                        en: "Body info & goal",
                        detail: nil,
                        identifier: "profile.editBody"
                    ) { isEditingProfile = true }

                    Rectangle().fill(DS.borderSubtle).frame(height: 1).padding(.leading, DS.s4)

                    settingsRow(
                        vi: "Apple Health",
                        en: "Health data",
                        detail: model.healthStatusText,
                        identifier: "profile.health"
                    ) { isShowingHealth = true }
                }
            }
        }
    }

    private func settingsRow(
        vi: String,
        en: String,
        detail: String?,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.s3) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(vi)
                        .hfStyle(HFType.rowLabel)
                        .foregroundStyle(DS.textStrong)
                    Text(detail ?? en)
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: DS.s2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.neutral300)
            }
            .padding(.horizontal, DS.s4)
            .frame(minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(vi), \(detail ?? en)")
    }

    // MARK: Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            Text("QUYỀN RIÊNG TƯ")
                .hfStyle(HFType.eyebrow)
                .foregroundStyle(DS.textSubtle)

            HFCard {
                VStack(alignment: .leading, spacing: DS.s3) {
                    // §6.13: "These are product commitments — implement them
                    // literally." Each line below is true of the app as built.
                    privacyLine("Dữ liệu sức khỏe được lưu trên thiết bị của bạn.")
                    privacyLine("Ảnh bữa ăn chỉ dùng tạm để phân tích rồi xoá.")
                    privacyLine("Dữ liệu sức khỏe không bao giờ được bán hay dùng cho quảng cáo.")
                }
            }
        }
    }

    private func privacyLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.s2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.green600)
            Text(text)
                .hfStyle(HFType.body)
                .foregroundStyle(DS.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Sheets

/// Reuses the four onboarding steps to edit an existing profile (§6.13).
private struct ProfileEditSheet: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var model: OnboardingModel?
    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    OnboardingView(model: model) {
                        onSaved()
                        dismiss()
                    }
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                        .font(.custom(DSFontName.medium, size: 15))
                }
            }
        }
        .task {
            guard model == nil else { return }
            let created = container.makeOnboardingModel()
            // Seed from the stored profile, otherwise editing silently resets
            // every field to the first-run defaults.
            if let stored = try? await container.user.load() {
                created.apply(stored.profile)
            }
            model = created
        }
    }
}

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
