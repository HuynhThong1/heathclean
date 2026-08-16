import SwiftUI

/// HISTORY_SPEC §6's states, each as its own view.
///
/// They are separate from `HistoryMonthsView` for one reason worth stating: a state
/// that only exists inside a `switch` in a screen can be looked at only by getting
/// the app into it, and "the store failed to read" is not a state a simulator enters
/// on request. Here each one has a preview.

/// Three day-card shapes while the first page loads.
///
/// §6 asks for the 1.4s pulse, and it is gated on Reduce Motion: this is the only
/// animation on a screen that does not otherwise move, so a user who asked for less
/// motion gets the same placeholder holding still. No spinner, and nothing says "no
/// data" before the read has finished — a loading History and an empty one look
/// nothing alike, on purpose.
struct HistorySkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animates: Bool { !reduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonBlock(width: 140, height: 14, animates: animates)
                .padding(.leading, DS.s1)
                .padding(.bottom, 2)
            ForEach(0..<3, id: \.self) { _ in
                card
            }
        }
        // One announcement for the whole placeholder; the grey boxes say nothing.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Đang tải lịch sử")
        .accessibilityIdentifier("history.skeleton")
    }

    private var card: some View {
        HStack(alignment: .top, spacing: DS.s3) {
            SkeletonBlock(width: 42, height: 40, animates: animates)
            VStack(alignment: .leading, spacing: 0) {
                SkeletonBlock(width: 120, height: 14, animates: animates)
                SkeletonBlock(height: 8, animates: animates)
                    .padding(.top, 10)
                SkeletonBlock(width: 90, height: 10, animates: animates)
                    .padding(.top, 8)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.rCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.rCard, style: .continuous)
                .strokeBorder(DS.borderSubtle, lineWidth: 1)
        }
    }
}

/// One grey block of the placeholder.
///
/// The pulse is on each block rather than on the container, so a block that takes its
/// width from the layout still animates and the card's own surface and border — which
/// are not placeholders — do not fade with it.
///
/// `DS.neutral150` rather than §6's #E3E9EF: the rule that no View hardcodes a hex
/// outranks a two-step difference in a placeholder nobody sees for a whole second.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var animates: Bool

    @State private var isDim = true

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(DS.neutral150)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(animates && isDim ? 0.45 : 0.95)
            .animation(
                animates ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true) : nil,
                value: isDim
            )
            .onAppear { isDim = false }
    }
}

/// A user who has logged nothing at all (§6).
///
/// It spells out the rule the screen works by — only logged days appear — because
/// without that an empty History reads as a bug rather than as an empty record.
struct HistoryEmptyState: View {
    let onScan: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HistoryStateBadge(symbol: "list.bullet", tint: .brand)
                .padding(.bottom, 18)
            Text("Chưa có bữa nào được ghi")
                .font(.custom(DSFontName.bold, size: 17))
                .foregroundStyle(DS.textStrong)
                .multilineTextAlignment(.center)
            Text(
                "Ghi bữa đầu tiên để bắt đầu lịch sử của bạn. Lịch sử chỉ hiện những ngày bạn đã ghi."
            )
            .font(.custom(DSFontName.regular, size: 13))
            .foregroundStyle(DS.textBody)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 270)
            .padding(.top, 10)

            // Orange, and this is the one place on the screen it is allowed: §3
            // reserves it for the scan action, and here the button *is* that action.
            Button("Quét bữa ăn", action: onScan)
                .buttonStyle(.ds(.accent, size: .large, fullWidth: true))
                .padding(.top, 20)
                .accessibilityIdentifier("history.empty.scan")

            Button("Nhập tay", action: onManualEntry)
                .buttonStyle(.ds(.secondary, size: .large, fullWidth: true))
                .padding(.top, 10)
                .accessibilityIdentifier("history.empty.manual")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}

/// A read that failed (§6): reassure first, then offer the retry.
///
/// No red and no warning icon. The store is on the device and the usual cause is
/// transient, so alarming someone about their own data would be both frightening and
/// factually wrong — the point of the middle line.
struct HistoryErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HistoryStateBadge(symbol: "arrow.clockwise", tint: .neutral)
                .padding(.bottom, 18)
            Text(message)
                .font(.custom(DSFontName.bold, size: 17))
                .foregroundStyle(DS.textStrong)
                .multilineTextAlignment(.center)
            Text("Dữ liệu vẫn nằm an toàn trên máy bạn. Thử lại sau vài giây.")
                .font(.custom(DSFontName.regular, size: 13))
                .foregroundStyle(DS.textBody)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .padding(.top, 10)
            Button("Thử lại", action: onRetry)
                .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                .padding(.top, 20)
                .accessibilityIdentifier("history.retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}

/// A search or a set of chips that matched nothing (§6).
///
/// The copy names the keyword when there is one and points at the chips either way:
/// a filter left on from a minute ago is at least as likely to be the reason as the
/// word just typed.
struct HistorySearchEmptyState: View {
    /// Empty when only chips are narrowing the list.
    let query: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Không tìm thấy bữa nào")
                .font(.custom(DSFontName.bold, size: 16))
                .foregroundStyle(DS.textStrong)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.custom(DSFontName.regular, size: 13))
                .foregroundStyle(DS.textBody)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .padding(.top, 10)
            Button("Xoá bộ lọc", action: onClear)
                .buttonStyle(.ds(.secondary, size: .large, fullWidth: true))
                .padding(.top, 18)
                .accessibilityIdentifier("history.search.reset")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var detail: String {
        guard !query.isEmpty else {
            return L("Không có bữa nào khớp bộ lọc trong các tháng đã tải. Thử bỏ bớt bộ lọc.")
        }
        return L("Không có bữa nào tên “\(query)” trong các tháng đã tải. Thử bỏ bớt bộ lọc.")
    }
}

/// The 56pt rounded square above an empty or error message.
///
/// A glyph, where the design draws a plain block: a block is a placeholder for an
/// illustration nobody has drawn, and an unlabelled grey square reads as something
/// that failed to load.
private struct HistoryStateBadge: View {
    enum Tint { case brand, neutral }

    let symbol: String
    let tint: Tint

    var body: some View {
        RoundedRectangle(cornerRadius: DS.rCard, style: .continuous)
            .fill(tint == .brand ? DS.chipOnBg : DS.surfaceSunken)
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(tint == .brand ? DS.blueOnSurface : DS.textMuted)
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Loading") {
        ScrollView {
            HistorySkeleton().padding(DS.s4)
        }
        .background(DS.surfacePage)
    }

    // No Reduce Motion preview: `accessibilityReduceMotion` is read-only in
    // `EnvironmentValues`, so the still variant can only be seen with the setting on
    // in the simulator — Settings › Accessibility › Motion.

    #Preview("Empty") {
        ScrollView {
            HistoryEmptyState(onScan: {}, onManualEntry: {}).padding(DS.s4)
        }
        .background(DS.surfacePage)
    }

    #Preview("Error") {
        ScrollView {
            HistoryErrorState(message: "Không đọc được dữ liệu", onRetry: {}).padding(DS.s4)
        }
        .background(DS.surfacePage)
    }

    #Preview("Search · nothing found") {
        ScrollView {
            VStack(spacing: DS.s6) {
                HistorySearchEmptyState(query: "bánh xèo", onClear: {})
                HistorySearchEmptyState(query: "", onClear: {})
            }
            .padding(DS.s4)
        }
        .background(DS.surfacePage)
    }
#endif
