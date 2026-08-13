import Domain
import SwiftUI

/// Meal history — handoff §6.11.
struct MealHistoryView: View {
    /// See `DashboardView.refreshID`.
    var refreshID: Int = 0

    @Environment(DependencyContainer.self) private var container
    @State private var model: MealHistoryModel?
    @State private var route: DetailRoute?
    @State private var toast: String?

    var body: some View {
        // §32's month grid replaces this screen rather than joining it, so only
        // one of the two is ever on screen — which is also why both can label
        // their day cells `history.day.<yyyy-MM-dd>`.
        if HistoryFeatureFlags.timeline {
            HistoryMonthsView(refreshID: refreshID)
        } else {
            weekStripScreen
        }
    }

    private var weekStripScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s5) {
                if let model {
                    if model.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Đang tải lịch sử bữa ăn")
                    } else if let message = model.errorMessage {
                        GrayNote(text: message)
                    } else if model.selectedDay.meals.isEmpty {
                        // Empty state reuses the neutral note style, no
                        // illustration (§6.11).
                        GrayNote(text: emptyText(for: model.selectedDate))
                    } else {
                        daySection(model.selectedDay, goal: model.dailyGoalCalories)
                    }
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
        // With the nav bar hidden nothing masks the top inset, so the title and
        // the day cards scrolled up through the clock and battery. The dashboard
        // already solves this the same way.
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, DS.s1)
                .padding(.bottom, DS.s3)
                .background(DS.surfacePage)
        }
        .hfToast(message: $toast)
        .navigationDestination(item: $route) { route in
            MealDetailRoute(
                type: route.type,
                meals: model?.meals(of: route.type, on: route.date) ?? [],
                dailyGoalCalories: model?.dailyGoalCalories ?? 0,
                // History is a record, not a place to keep eating from — adding
                // more belongs to today, which the dashboard owns.
                onAddMore: { self.route = nil },
                onChanged: {
                    Task { await model?.load() }
                },
                onDeleted: {
                    toast = "Đã xoá bữa ăn"
                    self.route = nil
                    Task { await model?.load() }
                }
            )
        }
        .task(id: refreshID) {
            if model == nil { model = container.makeMealHistoryModel() }
            await model?.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            HStack(alignment: .top, spacing: DS.s3) {
                Text("Bữa ăn đã ghi")
                    .font(.custom(DSFontName.extrabold, size: 29))
                    .tracking(-0.725)
                    .foregroundStyle(DS.textStrong)
                Spacer(minLength: 0)
            }

            // Pinned with the title rather than scrolled with the content: it is
            // how this screen is navigated, so it has to stay reachable.
            if let model {
                HistoryWeekStrip(
                    week: model.week,
                    selectedDate: model.selectedDate,
                    canGoForward: model.canGoForward,
                    onSelect: { model.select($0) },
                    onPrevious: { Task { await model.showPreviousWeek() } },
                    onNext: { Task { await model.showNextWeek() } }
                )
            }
        }
    }

    /// A day with nothing on it. Today gets the encouraging half of §6.11's copy;
    /// a past day is simply a day nothing was logged on.
    private func emptyText(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar.isDateInToday(date)
            ? String(localized: "Hôm nay chưa ghi bữa nào. Những bữa bạn ghi sẽ xuất hiện ở đây.")
            : String(localized: "Ngày này không có bữa ăn nào được ghi.")
    }

    private func daySection(_ day: MealHistoryModel.Day, goal: Double) -> some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
                Text(VietnameseDate.dayText(for: day.date))
                    .font(.custom(DSFontName.bold, size: 14))
                    .foregroundStyle(DS.textStrong)
                if goal > 0 {
                    Text("\(VNNumber.int(day.calories)) / \(VNNumber.int(goal))")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                }
                Spacer(minLength: DS.s2)
                Text("\(VNNumber.int(day.calories)) kcal")
                    .font(.custom(DSFontName.bold, size: 13))
                    .foregroundStyle(DS.textStrong)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(VietnameseDate.dayText(for: day.date)), \(VNNumber.int(day.calories)) kcal"
            )
            .accessibilityAddTraits(.isStaticText)

            dayProgress(consumed: day.calories, goal: goal)

            HFCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(day.meals.enumerated()), id: \.element.id) { index, meal in
                        mealRow(meal, on: day.date)
                        if index < day.meals.count - 1 {
                            Rectangle().fill(DS.borderSubtle)
                                .frame(height: 1)
                                .padding(.leading, 54)
                        }
                    }
                }
            }
        }
    }

    /// Blue under goal, neutral grey over — the same non-alarming treatment the
    /// dashboard ring uses (§4).
    private func dayProgress(consumed: Double, goal: Double) -> some View {
        let fraction = goal > 0 ? min(consumed / goal, 1) : 0
        let isOver = goal > 0 && consumed > goal
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(DS.neutral150)
                Capsule()
                    // Follows the dashboard ring's overflow arc.
                    .fill(isOver ? DS.danger : DS.blue)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private func mealRow(_ meal: Meal, on date: Date) -> some View {
        Button {
            route = DetailRoute(date: date, type: meal.type)
        } label: {
            mealRowLabel(meal)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history.meal.\(meal.type.rawValue)")
    }

    private func mealRowLabel(_ meal: Meal) -> some View {
        HStack(spacing: DS.s3) {
            Image(systemName: meal.type.chipSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.textBody)
                .frame(width: 28, height: 28)
                .background(meal.type.chipColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(meal.type.vi)
                    .font(.custom(DSFontName.semibold, size: 13.5))
                    .foregroundStyle(DS.textStrong)
                Text(meal.items.map(\.name).joined(separator: ", "))
                    .font(.custom(DSFontName.regular, size: 11))
                    .foregroundStyle(DS.textSubtle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: DS.s2)

            Text("\(VNNumber.int(meal.calories)) kcal")
                .font(.custom(DSFontName.bold, size: 13))
                .foregroundStyle(DS.textStrong)
        }
        .padding(.horizontal, DS.s4)
        .frame(minHeight: 54)
        // Without this the row only hit-tests where text is drawn, so the gap
        // between the name and the kcal figure is dead space — the case
        // CLAUDE.md records the dashboard rows already hitting.
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(meal.type.vi), \(VNNumber.int(meal.calories)) kcal")
    }
}

/// Which meal on which day the detail screen should open. History needs both,
/// where the dashboard only ever needs the type because it is always showing
/// today.
private struct DetailRoute: Identifiable, Hashable {
    let date: Date
    let type: MealType

    var id: String { "\(date.timeIntervalSince1970)-\(type.rawValue)" }
}
