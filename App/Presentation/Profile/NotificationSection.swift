import Domain
import SwiftUI
import UIKit

/// PROFILE_SPEC §3 — the five switches of handoff §6.13, split into two cards
/// by **when they fire** rather than listed flat.
///
/// The split is not cosmetic. The four in "Trong ngày" are consequences of
/// something the user just did; the one in "Cuối ngày" arrives whether or not
/// they opened the app, and it is the one that excludes the reminder beside it.
/// A flat list of five gave no way to say that except in prose.
///
/// **The switches stay inert until iOS has granted permission, and say so** —
/// the rule this section was held back for. A switch that schedules nothing is
/// a broken control; one drawn live over a denied permission is a broken
/// control that also lies about it.
struct NotificationSection: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.openURL) private var openURL

    /// §3's grouping. `NotificationPreference.allCases` is still the source of
    /// the set — these two arrays only say which card a switch is drawn in, so
    /// a preference added to Domain cannot silently vanish from the screen.
    private static let duringDay: [NotificationPreference] = [
        .seventyPercent, .nearTarget, .targetReached, .mealReminder
    ]
    private static let endOfDay: [NotificationPreference] = [.dailySummary]

    var body: some View {
        VStack(spacing: 0) {
            SectionLabel("THÔNG BÁO")

            authorizationBanner

            SectionSubheading("Trong ngày")
            card(Self.duringDay)

            SectionSubheading("Cuối ngày")
                .padding(.top, DS.s4)
            card(Self.endOfDay) {
                // Says out loud what `PlanNotificationsUseCase.dailySchedule`
                // decides. Two switches that quietly exclude each other read as
                // a bug, and this note is inside the card rather than under it
                // because it is about the switch directly above.
                Text("Buổi tối chỉ có một thông báo: tóm tắt nếu hôm đó bạn đã ghi bữa, nhắc ghi nếu chưa.")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.s4)
                    .padding(.bottom, 13)
            }
        }
    }

    private func card(
        _ preferences: [NotificationPreference],
        @ViewBuilder footer: () -> some View = { EmptyView() }
    ) -> some View {
        SettingsCard {
            ForEach(Array(preferences.enumerated()), id: \.element) { index, preference in
                if index > 0 { SettingsDivider() }
                row(preference)
            }
            footer()
        }
        // Dimmed *inside* the card, not over it: an opacity on the card itself
        // fades its fill into the page and takes the border with it, so the
        // section stops looking like a card at all — which reads as a rendering
        // fault rather than as a control waiting for permission.
        .opacity(isLive ? 1 : 0.5)
        .disabled(!isLive)
    }

    /// Written out rather than reusing `SettingsRow`: that declares itself one
    /// accessibility element with `.isStaticText`, and a control has to own its
    /// element or VoiceOver never announces the switch.
    private func row(_ preference: NotificationPreference) -> some View {
        Toggle(isOn: binding(for: preference)) {
            Text(verbatim: preference.label)
                .hfStyle(HFType.rowLabel)
                .foregroundStyle(DS.textStrong)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(DS.blue)
        .padding(.horizontal, DS.s4)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .accessibilityIdentifier("notification.\(preference.rawValue)")
        .accessibilityLabel(Text(verbatim: preference.label))
        .accessibilityValue(
            Text(verbatim: container.notifications.settings.isOn(preference) ? L("bật") : L("tắt"))
        )
    }

    private var isLive: Bool {
        container.notifications.authorization == .granted
    }

    @ViewBuilder
    private var authorizationBanner: some View {
        switch container.notifications.authorization {
        case .granted:
            EmptyView()
        case .notDetermined:
            VStack(alignment: .leading, spacing: DS.s3) {
                GrayNote(text: "Cần quyền thông báo của hệ thống trước khi bật các tuỳ chọn dưới đây.")
                Button {
                    Task { await container.notifications.requestAuthorization() }
                } label: {
                    Text("Bật thông báo")
                }
                .buttonStyle(.ds(.primary))
                .accessibilityIdentifier("notification.enable")
            }
            .padding(.bottom, DS.s4)
        case .denied:
            VStack(alignment: .leading, spacing: DS.s3) {
                GrayNote(text: "Thông báo đang tắt trong Cài đặt của iPhone. Chỉ Cài đặt mới bật lại được.")
                Button {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                } label: {
                    Text("Mở Cài đặt")
                }
                .buttonStyle(.ds(.ghost))
                .accessibilityIdentifier("notification.openSettings")
            }
            .padding(.bottom, DS.s4)
        }
    }

    private func binding(for preference: NotificationPreference) -> Binding<Bool> {
        let notifications = container.notifications
        return Binding(
            get: { notifications.settings.isOn(preference) },
            set: { isOn in
                notifications.settings.set(preference, on: isOn)
                // Turning the reminder on has to put one in the queue now rather
                // than at the next launch — this screen is the only place it can
                // be switched, so it is also the only place that can act on it.
                Task { await notifications.refresh() }
            }
        )
    }
}

// MARK: - Privacy

/// PROFILE_SPEC §4. Three lines, and the only green on the screen (§0).
///
/// Each is true of the app as built: health data is read on device and never
/// leaves it, a scanned photo is analysed and dropped by the gateway, and there
/// is no advertising or sale of anything. They are product commitments, not
/// decoration — if one stops being true the line comes out.
struct PrivacyCard: View {
    var body: some View {
        VStack(spacing: 0) {
            SectionLabel("QUYỀN RIÊNG TƯ")
            SettingsCard(padding: 15) {
                VStack(alignment: .leading, spacing: 12) {
                    line("Dữ liệu sức khoẻ được lưu trên thiết bị của bạn.")
                    line("Ảnh bữa ăn chỉ dùng tạm để phân tích rồi xoá.")
                    line("Dữ liệu sức khoẻ không bao giờ được bán hay dùng cho quảng cáo.")
                }
            }
        }
    }

    private func line(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.green)
                .frame(width: 17, height: 17)
                .padding(.top, 1)
            Text(text)
                .hfStyle(ProfileType.privacyLine)
                .foregroundStyle(DS.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Footer

/// §1's closing line, minus its link.
///
/// The reference page writes "HealthClean 1.0.0 (24) · Chính sách riêng tư".
/// **There is no privacy policy to open** — no URL, no in-app page — and a link
/// that cannot do what it says is the same broken control as a switch that
/// schedules nothing. The three commitments above it are the policy this build
/// actually has. Put the link back the day a page exists.
struct ProfileFooter: View {
    var body: some View {
        Text(verbatim: versionLine)
            .hfStyle(HFType.subLabel)
            .foregroundStyle(DS.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 18)
            .accessibilityIdentifier("profile.version")
    }

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let name = info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? "HealthClean"
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(name) \(version) (\(build))"
    }
}

// MARK: - Previews

#Preview("Quyền riêng tư · light") {
    PrivacyGallery().preferredColorScheme(.light)
}

#Preview("Quyền riêng tư · dark") {
    PrivacyGallery().preferredColorScheme(.dark)
}

private struct PrivacyGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PrivacyCard()
                ProfileFooter()
            }
            .padding(.horizontal, DS.s4)
        }
        .background(DS.surfacePage)
    }
}
