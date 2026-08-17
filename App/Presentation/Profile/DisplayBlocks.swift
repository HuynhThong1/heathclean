import SwiftUI
import UIKit

/// PROFILE_SPEC §2 — "Ngôn ngữ & giao diện", one card divided in two.
///
/// Both halves are `@AppStorage` read back at the app root (`HeathFirstApp`),
/// which is where `.environment(\.locale)` and `.preferredColorScheme` are
/// applied: they have to sit above every sheet, so a change made here reaches a
/// modal presented from here.
struct DisplaySettingsCard: View {
    let onLanguageChange: () -> Void

    var body: some View {
        SettingsCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: 18) {
                LanguageBlock(onChange: onLanguageChange)
                Rectangle().fill(DS.borderSubtle).frame(height: 1)
                AppearanceBlock()
            }
        }
    }
}

// MARK: - Language

/// §2's language half.
///
/// **Three options, not the two the reference page draws.** "Theo hệ thống"
/// already exists, works, and has a UI test; dropping it to match a picture
/// would remove a working preference — and it is the *right* default for a
/// language, unlike the appearance, because there is nothing invented about the
/// English. `AppLanguage` records the rest.
struct LanguageBlock: View {
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .system
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HFLabel("Ngôn ngữ")

            SegmentedTrack(
                selection: $language,
                options: AppLanguage.allCases.map { option in
                    SegmentedTrack.Option(
                        value: option,
                        label: option.label,
                        identifier: "profile.language.\(option.rawValue)",
                        accessibilityLabel: option.accessibilityLabel
                    )
                }
            )
        }
        // §2: no alert, no waiting screen, no relaunch — a `.selection` haptic
        // is the whole of the confirmation. The tree is rebuilt by `.id()` at
        // the root, which is what makes copy a model already resolved follow.
        .onChange(of: language) {
            UISelectionFeedbackGenerator().selectionChanged()
            onChange()
        }
    }
}

// MARK: - Appearance

/// §2's appearance half: a Toggle for "Theo hệ thống" above a Sáng/Tối
/// segmented control that dims when the Toggle is on.
///
/// The shape is the spec's, and the reason is stated there: "theo hệ thống" is
/// a third state, so it cannot be a third segment beside two that are mutually
/// exclusive with it.
///
/// **The default stays `.light`, not the `.system` the spec names**, and
/// `AppAppearance` carries the reason: every dark value in `DesignTokens.swift`
/// was derived in this repo rather than published by the brand team, and
/// following the system would hand that palette to anyone whose phone is dark
/// without their asking. The control is the spec's in full; only the value it
/// starts on differs.
struct AppearanceBlock: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .light

    var body: some View {
        AppearanceControls(appearance: $appearance)
    }
}

/// The controls themselves, over a binding rather than over storage.
///
/// Split out so §2's three states can each be *rendered* — a preview cannot put
/// `@AppStorage` into a chosen state, and "dựng đủ 3 trạng thái" is a
/// deliverable rather than a description.
struct AppearanceControls: View {
    @Binding var appearance: AppAppearance
    /// When `appearance == .system` the root passes `nil` to
    /// `preferredColorScheme`, so this is genuinely what iOS chose. Otherwise it
    /// is the app's own choice reflected back, which is why the caption below
    /// only quotes it in the `.system` branch.
    @Environment(\.colorScheme) private var colorScheme

    private var isFollowingSystem: Bool { appearance == .system }

    /// What the segmented control points at. While following the system it
    /// shows the system's answer rather than a stale stored one — §2's "con trỏ
    /// đặt ở giá trị hệ thống đang dùng".
    private var shownAppearance: Binding<AppAppearance> {
        Binding(
            get: {
                guard isFollowingSystem else { return appearance }
                return colorScheme == .dark ? .dark : .light
            },
            set: { appearance = $0 }
        )
    }

    private var followSystem: Binding<Bool> {
        Binding(
            get: { isFollowingSystem },
            set: { isOn in
                // Turning it off keeps what is on screen rather than snapping to
                // a default: the user was looking at one of the two, and the
                // switch is about who decides, not about which.
                appearance = isOn ? .system : (colorScheme == .dark ? .dark : .light)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Toggle(isOn: followSystem) {
                Text("Theo hệ thống")
                    .hfStyle(HFType.rowLabel)
                    .foregroundStyle(DS.textStrong)
            }
            .tint(DS.blue)
            .frame(minHeight: 44)
            .accessibilityIdentifier("profile.followSystemAppearance")
            .accessibilityLabel("Theo hệ thống")
            .accessibilityValue(Text(verbatim: isFollowingSystem ? L("bật") : L("tắt")))

            SegmentedTrack(
                selection: shownAppearance,
                options: [
                    SegmentedTrack.Option(
                        value: AppAppearance.light,
                        label: Text("Sáng"),
                        symbol: "sun.max",
                        identifier: "profile.appearance.light",
                        accessibilityLabel: L("Sáng")
                    ),
                    SegmentedTrack.Option(
                        value: AppAppearance.dark,
                        label: Text("Tối"),
                        symbol: "moon",
                        identifier: "profile.appearance.dark",
                        accessibilityLabel: L("Tối")
                    )
                ],
                isEnabled: !isFollowingSystem,
                disabledNote: L("đang theo hệ thống")
            )

            Text(verbatim: caption)
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("profile.appearance.caption")

            // Not part of §2, and kept because §2 does not know about it: the
            // dark palette in this repo is derived, not published. It is shown
            // only while dark is actually in effect — a standing disclaimer
            // under a light screen is noise, and the point is to be honest at
            // the moment the invented colours are on screen.
            if isDarkInEffect {
                Text("Bảng màu tối được suy ra trong dự án này, không phải màu chính thức của bộ nhận diện.")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var isDarkInEffect: Bool {
        appearance == .dark || (isFollowingSystem && colorScheme == .dark)
    }

    /// §2's caption table, verbatim.
    private var caption: String {
        switch appearance {
        case .system:
            let chosen = colorScheme == .dark ? L("Tối") : L("Sáng")
            return L("Đang theo hệ thống — hệ thống chọn \(chosen). Tắt để tự chọn.")
        case .light:
            return L("Tự chọn Sáng — app giữ nền sáng kể cả khi máy chuyển sang tối.")
        case .dark:
            return L("Tự chọn Tối — lựa chọn được lưu, không đổi theo máy nữa.")
        }
    }
}

// MARK: - Previews

#Preview("Ngôn ngữ & giao diện · light") {
    DisplayBlockGallery().preferredColorScheme(.light)
}

#Preview("Ngôn ngữ & giao diện · dark") {
    DisplayBlockGallery().preferredColorScheme(.dark)
}

#Preview("Ngôn ngữ & giao diện · accessibility3") {
    DisplayBlockGallery().environment(\.dynamicTypeSize, .accessibility3)
}

/// §2's table, all three rows, on a light system.
#Preview("Giao diện · 3 trạng thái") {
    AppearanceStateGallery().preferredColorScheme(.light)
}

/// The same three on a dark system, where only the first row's caption and
/// marker change — which is the whole claim the `.system` state makes.
#Preview("Giao diện · 3 trạng thái, máy tối") {
    AppearanceStateGallery().preferredColorScheme(.dark)
}

private struct DisplayBlockGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionLabel("NGÔN NGỮ & GIAO DIỆN")
                DisplaySettingsCard(onLanguageChange: {})
            }
            .padding(.horizontal, DS.s4)
        }
        .background(DS.surfacePage)
    }
}

private struct AppearanceStateGallery: View {
    @State private var system = AppAppearance.system
    @State private var light = AppAppearance.light
    @State private var dark = AppAppearance.dark

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // `verbatim`: preview scaffolding is not copy to translate, and
                // a literal in a `LocalizedStringKey` lands in the catalog
                // whether or not the app draws it.
                state("Mặc định của spec — theo hệ thống", binding: $system)
                state("Tự chọn Sáng", binding: $light)
                state("Tự chọn Tối", binding: $dark)
            }
            .padding(.horizontal, DS.s4)
        }
        .background(DS.surfacePage)
    }

    private func state(
        _ title: String,
        binding: Binding<AppAppearance>
    ) -> some View {
        VStack(spacing: 0) {
            SectionLabel(verbatim: title)
            SettingsCard(padding: DS.s4) {
                AppearanceControls(appearance: binding)
            }
        }
    }
}
