import SwiftUI

/// The tab roots that exist. §5 also specifies "Thống kê" (Insights) and a
/// raised orange scan action; both are omitted until they have something to
/// open — Insights needs weight history the Domain does not hold, and scanning
/// needs the AI pipeline. A tab that opens nothing is worse than an absent one.
enum MainTab: String, CaseIterable, Identifiable {
    case today, history, profile

    var id: String { rawValue }

    var vi: String {
        switch self {
        case .today: "Hôm nay"
        case .history: "Lịch sử"
        case .profile: "Tôi"
        }
    }

    var symbol: String {
        switch self {
        case .today: "circle.dashed.inset.filled"
        case .history: "clock"
        case .profile: "person"
        }
    }
}

struct MainTabView: View {
    @State private var selection: MainTab = .today

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selection {
                case .today:
                    NavigationStack {
                        DashboardView { selection = .profile }
                    }
                case .history:
                    NavigationStack { MealHistoryView() }
                case .profile:
                    NavigationStack { ProfileView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HFTabBar(selection: $selection)
        }
        .background(DS.surfacePage)
    }
}

/// §5: 86pt tall, translucent white over a blur, 1px top border, 23pt icons,
/// 10.5pt labels, active brand blue and inactive neutral-400.
struct HFTabBar: View {
    @Binding var selection: MainTab

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
            }
        }
        .padding(.horizontal, DS.s2)
        .padding(.top, DS.s2)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.borderSubtle).frame(height: 1)
        }
    }
}
