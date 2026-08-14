import Domain
import SwiftUI

/// The History tab — HISTORY_SPEC.md, which supersedes the handoff README's §6.11
/// for this screen.
///
/// A continuous scroll of the days something was logged on, newest first, under a
/// pinned header holding the title, the search field and the filter chips. There is
/// **no month grid**: §0.1 rules out drawing a cell for a day with no data, which is
/// what the calendar this replaced spent nine tenths of its pixels on.
///
/// This is the History tab outright. It spent one release behind a feature flag
/// beside a week-strip screen (§32.7's "bật flag cho nội bộ trước"); both the flag
/// and the strip are gone, because two ways to navigate one screen is not a
/// shipping state (§32.2) and HISTORY_SPEC is chốt.
///
/// **The keyword and the chips are not kept between two visits to the tab** (§5).
/// That falls out of where they live: `MainTabView` switches on its selection, so
/// leaving History tears this view down and its `model` with it. It is worth knowing
/// that is load-bearing rather than incidental — moving the model up to the tab shell
/// would silently make a search survive.
struct HistoryMonthsView: View {
    /// See `DashboardView.refreshID`.
    var refreshID: Int = 0
    /// Asks the tab shell to open the scan flow, because it owns that cover. §6's
    /// empty state offers it as the first action.
    var onScanRequested: ((MealType) -> Void)?

    @Environment(DependencyContainer.self) private var container
    @State private var model: HistoryMonthsModel?
    @State private var toast: String?
    /// Manual entry, offered beside the scan on the empty state. Owned here because
    /// this screen presents it; the dashboard owns its own copy of the same sheet.
    @State private var entryType: MealType?

    var body: some View {
        ScrollView {
            stateBody
                .padding(.horizontal, DS.s4)
                .padding(.top, DS.s3)
                .padding(.bottom, 34)
                // §5: while a keystroke waits out its debounce the previous list
                // stays and dims. No spinner, and above all no blank screen between
                // two letters of the same word.
                .opacity(model?.isFiltering == true ? 0.5 : 1)
        }
        .scrollIndicators(.hidden)
        .background(DS.surfacePage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        // Pinned, not scrolled (§1). With the nav bar hidden nothing else masks the
        // top inset, so without this the title runs up through the clock and battery.
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .hfToast(message: $toast)
        .sheet(isPresented: daySheetBinding) {
            if let model, let day = model.selectedDay {
                HistoryDayPanelSheet(
                    day: day,
                    goal: model.goal,
                    isToday: day.date == model.today,
                    onChanged: { Task { await model.load() } },
                    onDeleted: {
                        model.clearSelection()
                        toast = "Đã xoá bữa ăn"
                        Task { await model.load() }
                    }
                )
            }
        }
        .sheet(item: $entryType) { type in
            MealEntryView(
                type: type,
                onSaved: { calories in
                    toast = "Đã lưu bữa ăn · \(VNNumber.int(calories)) kcal"
                    Task { await model?.load() }
                },
                onScanInstead: onScanRequested.map { request in
                    {
                        entryType = nil
                        request(type)
                    }
                }
            )
        }
        .task(id: refreshID) {
            if model == nil { model = container.makeHistoryMonthsModel() }
            await model?.load()
        }
    }

    // MARK: Header

    /// §2: 16 horizontal, safe area + 8 above, 12 below, on the card surface with a
    /// hairline under it.
    ///
    /// The search box and the chips live here rather than in a sheet or the
    /// navigation bar so the keyword, the chips and the results are visible at once —
    /// a filter you cannot see is one you forget you set, which is exactly why §6's
    /// "not found" copy has to point at the chips.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            HistorySearchField(
                text: Binding(
                    get: { model?.searchText ?? "" },
                    set: { model?.updateSearch($0) }
                )
            )
            .padding(.top, 14)
            HistoryFilterChipRow(selected: model?.filters ?? []) { filter in
                model?.toggle(filter)
            }
            .padding(.top, DS.s3)
        }
        .padding(.horizontal, DS.s4)
        .padding(.top, DS.s2)
        .padding(.bottom, DS.s3)
        .background(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                DS.surfaceCard
                Rectangle().fill(DS.borderSubtle).frame(height: 1)
            }
        }
    }

    /// §1's `LabelPair`, at screen-title size. The component itself is 14.5/11.5 —
    /// what a title needs is the pair *pattern*, not the pair view.
    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Lịch sử")
                .font(.custom(DSFontName.bold, size: 26))
                .tracking(-0.26)
                .foregroundStyle(DS.textStrong)
            Text("History")
                .font(.custom(DSFontName.regular, size: 11.5))
                .foregroundStyle(DS.textMuted)
        }
        .padding(.horizontal, DS.s1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lịch sử, History")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("history.title")
    }

    // MARK: The state machine (§1, §6)

    @ViewBuilder
    private var stateBody: some View {
        if let model {
            if model.isLoading {
                HistorySkeleton()
            } else if let message = model.errorMessage, model.months.isEmpty {
                // A page that failed mid-list is reported by the footer instead:
                // discarding the months that did load would lose the user's place in
                // order to report a failure that never touched them.
                HistoryErrorState(message: message) {
                    Task { await model.load() }
                }
            } else if model.isEmpty {
                HistoryEmptyState(
                    onScan: { onScanRequested?(MealType.suggestedForNow()) },
                    onManualEntry: { entryType = MealType.suggestedForNow() }
                )
            } else if model.isSearchActive {
                searchBody(model)
            } else {
                loadedBody(model)
            }
        } else {
            HistorySkeleton()
        }
    }

    private func loadedBody(_ model: HistoryMonthsModel) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(model.feed) { item in
                switch item {
                case .month(let month):
                    HistoryMonthSection(
                        month: month,
                        fallbackGoalCalories: model.dailyGoalCalories,
                        today: model.today,
                        onSelect: { model.select($0) }
                    )
                case .emptyMonth(let year, let month):
                    EmptyMonthDivider(year: year, month: month)
                        .padding(.vertical, 8)
                }
            }
            paginationFooter(model)
                .padding(.top, DS.s4)
        }
    }

    // MARK: Search (§5)

    private func searchBody(_ model: HistoryMonthsModel) -> some View {
        LazyVStack(alignment: .leading, spacing: 9) {
            // Only over results. "0 bữa có “comxxx”" above "Không tìm thấy bữa nào"
            // says the same thing twice, and §6 draws the not-found state on its own.
            if !model.results.isEmpty {
                Text(model.resultsHeader)
                    .font(.custom(DSFontName.regular, size: 11.5))
                    .foregroundStyle(DS.textMuted)
                    .padding(.horizontal, 2)
                    .padding(.bottom, DS.s1)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("history.results.header")
            }

            if model.results.isEmpty {
                HistorySearchEmptyState(query: model.activeQuery) { model.clearSearch() }
            } else {
                ForEach(model.results) { hit in
                    MealResultRow(hit: hit) { model.selectDay(of: hit) }
                }
                // §5 asks for this line always: a search that quietly covered only
                // the last three months would look like an answer about all of them.
                // `textMuted`, not the design's lighter grey: §7 requires a small grey
                // on `pageBg` to carry its contrast, and this line is load-bearing —
                // it says what the search did *not* cover.
                Text("Tìm trong các tháng đã tải. Kéo xuống để tải thêm.")
                    .font(.custom(DSFontName.regular, size: 11.5))
                    .foregroundStyle(DS.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.s1)
                paginationFooter(model)
            }
        }
        // §7: the count changing is the outcome of typing, and nothing else on screen
        // announces it — the list itself is below the keyboard.
        .onChange(of: model.results.count) { _, count in
            AccessibilityNotification.Announcement(String(localized: "\(count) kết quả")).post()
        }
    }

    // MARK: Pagination (§6)

    @ViewBuilder
    private func paginationFooter(_ model: HistoryMonthsModel) -> some View {
        VStack(spacing: DS.s2) {
            if let message = model.errorMessage, !model.months.isEmpty {
                Text(message)
                    .font(.custom(DSFontName.regular, size: 11.5))
                    .foregroundStyle(DS.textMuted)
                    .multilineTextAlignment(.center)
            }
            if model.canLoadMore {
                if model.isLoadingMore {
                    // Text, not a spinner: it says *what* is being fetched, which is
                    // the one thing a spinner cannot.
                    Text(loadingText(model))
                        .font(.custom(DSFontName.regular, size: 11.5))
                        .foregroundStyle(DS.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("history.loadingMore")
                } else {
                    // **Tapped, never automatic.** §32.3 asked for a load as the end
                    // of the list neared, and a `.task` on a footer inside a
                    // `LazyVStack` is not that: the stack materialises views ahead of
                    // the viewport, so the next page arrived before the footer was
                    // ever on screen — and it churned the list mid-scroll.
                    Button("Tải các tháng trước") {
                        Task { await model.loadMore() }
                    }
                    .buttonStyle(.ds(.secondary, size: .large, fullWidth: true))
                    .accessibilityIdentifier("history.loadMore")
                }
            } else {
                Text("Đã hiển thị toàn bộ lịch sử.")
                    .font(.custom(DSFontName.regular, size: 11.5))
                    .foregroundStyle(DS.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.s1)
                    .accessibilityIdentifier("history.exhausted")
            }
        }
    }

    /// "Đang tải tháng 3, 2026…" — the month, lowercased, because it lands
    /// mid-sentence (§6).
    private func loadingText(_ model: HistoryMonthsModel) -> String {
        guard let label = model.loadingMonthLabel else {
            return String(localized: "Đang tải…")
        }
        return String(localized: "Đang tải \(label.lowercased())…")
    }

    /// The sheet is driven by the model's selection rather than by local state, so a
    /// refresh after an edit rebuilds the day it is showing instead of leaving stale
    /// meals on screen.
    private var daySheetBinding: Binding<Bool> {
        Binding(
            get: { model?.selectedDate != nil },
            set: { isPresented in
                if !isPresented { model?.clearSelection() }
            }
        )
    }
}
