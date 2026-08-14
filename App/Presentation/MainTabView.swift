import Domain
import SwiftUI

/// §5's four tab roots, in its order, with the raised scan action between
/// History and Insights.
enum MainTab: String, CaseIterable, Identifiable {
    case today, history, insights, profile

    var id: String { rawValue }

    var vi: String {
        switch self {
        case .today: "Hôm nay"
        case .history: "Lịch sử"
        case .insights: "Thống kê"
        case .profile: "Tôi"
        }
    }

    /// §8's icon table. Today and History had `clock` the wrong way round, which
    /// read as two swapped tabs rather than as a different choice.
    var symbol: String {
        switch self {
        case .today: "clock"
        case .history: "list.bullet"
        case .insights: "chart.bar"
        case .profile: "person.crop.circle"
        }
    }
}

struct MainTabView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: MainTab = .today
    @State private var scanType: MealType?
    @State private var toast: String?

    /// Bumped whenever something outside a tab root writes a meal, so the roots
    /// know to re-read.
    ///
    /// The scan flow is owned here, not by the dashboard, so saving from it had
    /// no way to reach the dashboard's model — and because the scan button lives
    /// on the tab bar, the user is usually *already* on Hôm nay, which makes
    /// `selection = .today` a no-op: the `switch` branch does not change, the view
    /// is never rebuilt, and its `.task` never runs again. The figures simply
    /// stayed as they were. Manual entry never showed this because the dashboard
    /// owns that sheet and reloads itself.
    @State private var dataVersion = 0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selection {
                case .today:
                    NavigationStack {
                        DashboardView(
                            onScanRequested: { scanType = $0 },
                            refreshID: dataVersion
                        )
                    }
                case .history:
                    NavigationStack {
                        HistoryMonthsView(
                            refreshID: dataVersion,
                            onScanRequested: { scanType = $0 }
                        )
                    }
                case .insights:
                    NavigationStack { InsightsView(refreshID: dataVersion) }
                case .profile:
                    NavigationStack { ProfileView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HFTabBar(selection: $selection) {
                // §5's raised action. Defaulting to snack would be arbitrary,
                // so the scan opens on the meal type the time of day suggests.
                scanType = MealType.suggestedForNow()
            }
        }
        .background(DS.surfacePage)
        .hfToast(message: $toast)
        .fullScreenCover(item: $scanType) { type in
            ScanFlowView(type: type) { calories in
                toast = "Đã lưu bữa ăn · \(VNNumber.int(calories)) kcal"
                // Every root re-reads, not just the one in front: history and
                // insights are as stale as the dashboard after a scan.
                dataVersion += 1
                selection = .today
                // The scan can be started from any tab, so the dashboard's own
                // hook is not guaranteed to run. §19's thresholds have to be
                // re-checked here or a scan from History announces nothing.
                Task { await container.notifications.refresh() }
            }
        }
        // `onChange` does not fire for the phase the app launches in, and the
        // dashboard's own hook cannot help until the system authorization has
        // been read back at least once.
        .task { await container.notifications.refresh() }
        // Notifications are re-planned on the way in, not only after a change:
        // the system authorization can be switched off in Settings while the app
        // is away, and the evening's plan is only ever made for today.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await container.notifications.refresh() }
        }
    }
}

/// §5: 86pt tall, translucent white over a blur, 1px top border, 23pt icons,
/// 10.5pt labels, active brand blue and inactive neutral-400.
struct HFTabBar: View {
    @Binding var selection: MainTab
    let onScan: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: DS.s1) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 21, weight: .semibold))
                        Text(tab.vi)
                            .font(.custom(DSFontName.semibold, size: 10.5))
                    }
                    .foregroundStyle(selection == tab ? DS.blue : DS.neutral400)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)

                // The scan action sits between History and Profile, as §5 draws
                // it, raised above the bar.
                if tab == .history { scanButton }
            }
        }
        .padding(.horizontal, DS.s2)
        .padding(.top, DS.s2)
        // §5 is white at 94% *over* a blur, and both halves matter. The material
        // alone samples whatever is behind it, which on a device rendered the
        // whole bar as a grey slab and left the inactive `neutral400` labels
        // barely readable on it. The simulator did not show this.
        //
        // The 1px top border belongs in the *background*, not in an `.overlay`.
        // As an overlay it was composited after the HStack — which holds the
        // raised scan button — and drew a line straight across the button, since
        // `.offset` moves the button out of the bar visually while leaving the
        // layout frame, and therefore the border, where it was.
        //
        // `.ignoresSafeArea(edges: .bottom)` because this is the ViewBuilder
        // overload of `background`, which — unlike the ShapeStyle one — stops at
        // the safe area. Without it the bar floated with a 34pt strip of page
        // grey beneath it and the home indicator sitting on that strip, and §5's
        // 86pt height is only reachable if the bar owns the bottom inset.
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                // `DS.surfaceCard`, not `Color.white`: §5's value is white
                // because §5 is light-only, and a hardcoded white bar under a
                // dark app would be the brightest thing on the screen.
                DS.surfaceCard.opacity(0.94).background(.ultraThinMaterial)
                Rectangle().fill(DS.borderSubtle).frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var scanButton: some View {
        Button(action: onScan) {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(DS.orange, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                .shadow(color: DS.orange.opacity(0.42), radius: 10, y: 8)
        }
        .buttonStyle(.plain)
        .frame(width: 76)
        .offset(y: -24)
        .accessibilityIdentifier("tab.scan")
        .accessibilityLabel("Quét bữa ăn")
    }
}
