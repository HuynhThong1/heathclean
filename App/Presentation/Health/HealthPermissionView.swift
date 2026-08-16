import Domain
import SwiftUI

/// The data types the app can read, as presented on the permission screen
/// (§6.3). The switches express *intent* — which types to ask for — not the
/// granted state, which HealthKit never reveals for reads.
enum HealthDataKind: String, CaseIterable, Identifiable {
    case steps, energy, sleep, weight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .steps: L("Bước chân")
        case .energy: L("Năng lượng vận động")
        case .sleep: L("Giấc ngủ")
        case .weight: L("Cân nặng & BMI")
        }
    }

    /// §6.3 pairs "Cân nặng & BMI" with body mass; BMI is derived, not read.
    var dataTypes: [HealthDataType] {
        switch self {
        case .steps: [.steps]
        case .energy: [.activeEnergy]
        case .sleep: [.sleep]
        case .weight: [.bodyMass]
        }
    }

    var symbol: String {
        switch self {
        case .steps: "figure.walk"
        case .energy: "flame"
        case .sleep: "bed.double"
        case .weight: "scalemass"
        }
    }
}

/// Apple Health permissions — handoff §6.3.
struct HealthPermissionView: View {
    @Bindable var model: OnboardingModel

    /// Returns to onboarding's last step, so the goal can still be changed
    /// after seeing it.
    let onBack: () -> Void
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.s5) {
                    HFBackChip { onBack() }
                        .accessibilityIdentifier("health.back")
                    heading
                    permissionCard
                    GrayNote(
                        text: "Dữ liệu Apple Health không rời khỏi thiết bị và không dùng cho quảng cáo."
                    )
                    if let message = model.healthMessage {
                        DSFieldMessage(text: message, isError: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, DS.s5)
                .padding(.bottom, DS.s6)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .background(DS.surfacePage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DS.danger)
                .frame(width: 56, height: 56)
                .background(DS.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DS.borderSubtle, lineWidth: 1)
                }

            Text("Kết nối Apple Health")
                .font(.custom(DSFontName.extrabold, size: 27))
                .tracking(-0.54)
                .foregroundStyle(DS.textStrong)
                .fixedSize(horizontal: false, vertical: true)

            Text("HealthClean chỉ đọc những gì bạn cho phép. Ứng dụng vẫn hoạt động đầy đủ nếu bạn từ chối.")
                .hfStyle(HFType.body)
                .foregroundStyle(DS.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionCard: some View {
        HFCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(HealthDataKind.allCases.enumerated()), id: \.element) { index, kind in
                    row(kind)
                    if index < HealthDataKind.allCases.count - 1 {
                        Rectangle().fill(DS.borderSubtle)
                            .frame(height: 1)
                            .padding(.leading, 64)
                    }
                }
            }
        }
    }

    private func row(_ kind: HealthDataKind) -> some View {
        HStack(spacing: DS.s3) {
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.blue)
                .frame(width: 32, height: 32)
                .background(DS.blue50, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            HFLabel(verbatim: kind.label)

            Spacer(minLength: DS.s2)

            Toggle(
                "",
                isOn: Binding(
                    get: { model.requestedHealthKinds.contains(kind) },
                    set: { model.setHealthKind(kind, requested: $0) }
                )
            )
            .labelsHidden()
            .tint(DS.blue)
            .accessibilityIdentifier("health.\(kind.rawValue)")
            .accessibilityLabel(kind.label)
        }
        .padding(.horizontal, DS.s4)
        .frame(minHeight: 62)
    }

    private var bottomBar: some View {
        VStack(spacing: DS.s2) {
            Button("Cho phép truy cập") {
                Task {
                    await model.connectAppleHealth()
                    onFinished()
                }
            }
            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
            .disabled(model.requestedHealthKinds.isEmpty || model.isConnectingHealth)
            .accessibilityIdentifier("health.allow")

            Button("Để sau") { onFinished() }
                .buttonStyle(.ds(.ghost, size: .medium))
                .accessibilityIdentifier("health.later")
        }
        .padding(.horizontal, 20)
        .padding(.top, DS.s3)
        .padding(.bottom, DS.s2)
        .background(DS.surfaceCard)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.borderSubtle).frame(height: 1)
        }
    }
}
