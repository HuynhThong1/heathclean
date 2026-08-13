import Domain
import SwiftUI

/// §32's history screen: a continuous vertical scroll of month cards, newest at
/// the top, with the day sheet as the way into a meal.
///
/// It sits beside the week-strip screen behind `HistoryFeatureFlags.timeline`
/// until stages 2 and 3 land. At stage 4 this becomes `MealHistoryView` and the
/// strip goes (§32.2 item 6 — two ways to navigate the same screen is not the
/// shipping state).
struct HistoryMonthsView: View {
    /// See `DashboardView.refreshID`.
    var refreshID: Int = 0

    @Environment(DependencyContainer.self) private var container
    @State private var model: HistoryMonthsModel?
    @State private var toast: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.s4) {
                if let model {
                    if model.isLoading {
                        skeleton
                    } else if let message = model.errorMessage {
                        retry(message: message, model: model)
                    } else {
                        if model.isEmpty {
                            GrayNote(
                                text: String(
                                    localized: "Chưa ghi bữa nào. Những bữa bạn ghi sẽ xuất hiện trên lịch này."
                                )
                            )
                        }
                        ForEach(model.visibleMonths) { month in
                            HistoryMonthSection(
                                month: month,
                                today: model.today,
                                onSelect: { model.select($0) }
                            )
                        }
                        if model.canLoadMore {
                            loadMoreButton(model)
                        }
                    }
                } else {
                    skeleton
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
        // With the nav bar hidden nothing masks the top inset, so the title
        // scrolled up through the clock and battery.
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Bữa ăn đã ghi")
                .font(.custom(DSFontName.extrabold, size: 29))
                .tracking(-0.725)
                .foregroundStyle(DS.textStrong)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, DS.s1)
                .padding(.bottom, DS.s3)
                .background(DS.surfacePage)
        }
        .hfToast(message: $toast)
        .sheet(isPresented: daySheetBinding) {
            if let model, let day = model.selectedDay {
                HistoryDaySheet(
                    day: day,
                    goalCalories: model.dailyGoalCalories,
                    onChanged: { Task { await model.load() } },
                    onDeleted: {
                        model.clearSelection()
                        toast = "Đã xoá bữa ăn"
                        Task { await model.load() }
                    }
                )
            }
        }
        .task(id: refreshID) {
            if model == nil { model = container.makeHistoryMonthsModel() }
            await model?.load()
        }
    }

    /// The shape of a month section while the first page loads (§32.2 item 5).
    ///
    /// Deliberately **still**: a shimmer would be motion on every cold open, and
    /// the list it stands in for does not move either. There is nothing here for
    /// Reduce Motion to turn off.
    private var skeleton: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DS.neutral150)
                .frame(width: 120, height: 12)
                .padding(.horizontal, DS.s1)
            HFCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { index in
                        HStack(spacing: DS.s3) {
                            RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                                .fill(DS.neutral150)
                                .frame(
                                    width: HistoryDayRow.thumbnailSide,
                                    height: HistoryDayRow.thumbnailSide
                                )
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(DS.neutral150)
                                    .frame(width: 130, height: 12)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(DS.neutral150)
                                    .frame(width: 90, height: 10)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, DS.s4)
                        .padding(.vertical, DS.s3)
                        if index < 3 {
                            Rectangle().fill(DS.borderSubtle).frame(height: 1)
                                .padding(.leading, HistoryDayRow.thumbnailSide + DS.s4 + DS.s3)
                        }
                    }
                }
            }
        }
        // One announcement for the whole placeholder; the grey boxes say nothing.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Đang tải lịch sử bữa ăn")
    }

    /// A read that failed is offered again rather than just reported: the store is
    /// local, so the usual cause is transient and the user can do something about
    /// it — which a bare grey note does not let them (§32.2 item 5).
    private func retry(message: String, model: HistoryMonthsModel) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            GrayNote(text: message)
            Button {
                Task { await model.load() }
            } label: {
                Text("Thử lại")
                    .font(.custom(DSFontName.semibold, size: 14))
                    .foregroundStyle(DS.blueOnSurface)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("history.retry")
        }
    }

    /// The sheet is driven by the model's selection rather than by local state,
    /// so a refresh after an edit rebuilds the day it is showing instead of
    /// leaving stale meals on screen.
    private var daySheetBinding: Binding<Bool> {
        Binding(
            get: { model?.selectedDate != nil },
            set: { isPresented in
                if !isPresented { model?.clearSelection() }
            }
        )
    }

    /// **Tapped, never automatic.** §32.3 asks for a load as the end of the list
    /// nears, and `.task` on a footer inside a `LazyVStack` is not that: the stack
    /// materialises views ahead of the viewport, so the next page arrived before
    /// the footer was ever on screen — visible in a test that asserted an
    /// out-of-window month was *not* loaded yet, and it churned the list while the
    /// user was scrolling. A button that says what it does is also the thing a
    /// test can point at.
    private func loadMoreButton(_ model: HistoryMonthsModel) -> some View {
        Button {
            Task { await model.loadMore() }
        } label: {
            Group {
                if model.isLoadingMore {
                    ProgressView()
                } else {
                    Text("Xem các tháng trước")
                        .font(.custom(DSFontName.semibold, size: 14))
                        .foregroundStyle(DS.blueOnSurface)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history.loadMore")
    }
}
