import Domain
import SwiftUI

/// The tab roots that exist. §5 also specifies "Thống kê" (Insights), omitted
/// until it has something to open — it needs weight history the Domain does not
/// hold. The raised scan action is present.
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
    @State private var scanType: MealType?
    @State private var toast: String?

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
                // Bring the dashboard forward so the new total is visible.
                selection = .today
            }
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
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.borderSubtle).frame(height: 1)
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
