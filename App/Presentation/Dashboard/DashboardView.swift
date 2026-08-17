import Domain
import SwiftUI

/// Dashboard — handoff README §6.4, ring variant.
///
/// Cards on the cool page background rather than a grouped `List`: section
/// headings sit *outside* the cards, which a `List` cannot express.
struct DashboardView: View {
    /// Asks the tab shell to open the scan flow, because it owns that cover.
    /// Manual entry offers this for a user who meant to scan.
    var onScanRequested: ((MealType) -> Void)?
    /// Changes when a meal is written from outside this screen — the scan flow —
    /// so `.task(id:)` re-reads. `.task` alone runs once per appearance, and this
    /// view is not rebuilt when the tab it is already on is re-selected.
    var refreshID: Int = 0

    @Environment(DependencyContainer.self) private var container
    @State private var model: DashboardModel?
    @State private var entryType: MealType?
    @State private var detailType: MealType?
    @State private var toast: String?

    var body: some View {
        Group {
            if let model, let summary = model.summary {
                content(model: model, summary: summary)
            } else if let message = model?.errorMessage {
                ContentUnavailableView(
                    "Không tải được hôm nay",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            } else {
                ProgressView()
            }
        }
        .background(DS.surfacePage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: refreshID) {
            if model == nil { model = container.makeDashboardModel() }
            await model?.load()
        }
        .sheet(item: $entryType) { type in
            MealEntryView(
                type: type,
                onSaved: { savedCalories in
                    toast = L("Đã lưu bữa ăn · \(AppNumber.int(savedCalories)) kcal")
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
        .hfToast(message: $toast)
    }

    private func content(model: DashboardModel, summary: DailyNutritionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s6) {
                heroCard(model: model, summary: summary)
                macrosSection(summary: summary)
                // Absent until the store has answered, rather than drawn at
                // 0 / 0 while it does — an empty bar that fills a moment later
                // reads as a figure that changed.
                if let water = model.water { waterSection(water) }
                mealsSection(summary: summary)
                healthSection(model: model)
                if let bmi = model.bmi { bmiRow(bmi: bmi) }
            }
            .padding(.horizontal, 20)
            .padding(.top, DS.s2)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        // The design has no navigation bar, so nothing would mask content
        // scrolling up into the status bar — section headings collided with the
        // clock. Pinning the header here gives that job to an opaque strip.
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, DS.s2)
                .padding(.bottom, DS.s3)
                .background(DS.surfacePage)
        }
        .navigationDestination(item: $detailType) { type in
            MealDetailRoute(
                type: type,
                meals: summary.meals(of: type),
                dailyGoalCalories: summary.goal.calories,
                onAddMore: {
                    detailType = nil
                    entryType = type
                },
                onChanged: {
                    Task { await self.model?.load() }
                },
                onDeleted: {
                    toast = L("Đã xoá bữa ăn")
                    Task { await self.model?.load() }
                }
            )
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            // §6.4 opens with an eyebrow above the date, and it is not
            // decoration: without it a 29pt title sits four points under the
            // clock with nothing between them. 2pt, because the two lines are
            // meant to read as one block.
            VStack(alignment: .leading, spacing: 2) {
                Text("HÔM NAY")
                    .hfStyle(HFType.eyebrow)
                    .foregroundStyle(DS.textSubtle)
                Text(AppDate.headerText(for: Date()))
                    .hfStyle(HFType.screenTitle)
                    .foregroundStyle(DS.textStrong)
            }
            Spacer(minLength: DS.s3)

            // §6.4 puts an avatar here that opens Profile, and it was right when
            // it was written — there was no tab bar. Now that §5's "Tôi" tab
            // exists it is a second door to the same room, three inches from the
            // first, and it was also a 38pt target under §4's 44pt floor.
        }
    }

    // MARK: Hero

    private func heroCard(model: DashboardModel, summary: DailyNutritionSummary) -> some View {
        HFCard(padding: 20, radius: DS.rHero) {
            VStack(spacing: DS.s5) {
                ZStack {
                    CalorieRing(fraction: summary.budget.fractionUsed)
                    // Bounded by the ring's *inner* diameter — 214 less the 17pt
                    // stroke either side (§6.4) — and not by the card. The ZStack
                    // is card-width, so the centre text's layout limit was ~250pt
                    // against a 180pt hole: a four-digit value at a larger text
                    // size crossed the blue stroke before `minimumScaleFactor`
                    // was forced to do anything.
                    ringCentre(summary: summary)
                        .frame(maxWidth: 214 - 17 * 2)
                }
                .frame(maxWidth: .infinity)

                statsRow(model: model, summary: summary)

                if let note = BudgetCopy.note(
                    for: model.status,
                    remainingKcal: summary.budget.remaining
                ) {
                    GrayNote(verbatim: note)
                }
            }
        }
    }

    private func ringCentre(summary: DailyNutritionSummary) -> some View {
        let remaining = summary.budget.remaining
        let overBudget = remaining < 0

        return VStack(spacing: 2) {
            Text(AppNumber.int(abs(remaining)))
                .hfStyle(HFType.heroMetric)
                .foregroundStyle(DS.textStrong)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(overBudget ? "vượt mục tiêu" : "kcal còn lại")
                .hfStyle(HFType.caption)
                // Matches the overflow arc so the two halves of the same signal
                // agree. The big number stays `textStrong`: it is the figure, and
                // colouring it too would shout.
                .foregroundStyle(overBudget ? DS.danger : DS.textBody)
        }
        .padding(.horizontal, DS.s6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            overBudget
                ? "\(AppNumber.int(abs(remaining))) kcal vượt mục tiêu"
                : "\(AppNumber.int(abs(remaining))) kcal còn lại"
        )
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("hero.remaining")
    }

    private func statsRow(model: DashboardModel, summary: DailyNutritionSummary) -> some View {
        HStack(spacing: 0) {
            heroStat(
                value: AppNumber.int(summary.goal.calories),
                label: "Mục tiêu"
            )
            divider
            heroStat(
                value: AppNumber.int(summary.consumedCalories),
                label: "Đã ăn"
            )
            divider
            heroStat(
                // "—" when Health isn't connected (§6.4).
                value: model.health?.activeEnergyKcal.map { AppNumber.int($0) } ?? "—",
                label: "Vận động"
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.borderSubtle)
            .frame(width: 1, height: 34)
    }

    private func heroStat(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .hfStyle(HFType.statValue)
                .foregroundStyle(DS.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .hfStyle(HFType.subLabelSemibold)
                .foregroundStyle(DS.textMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label) + Text(verbatim: ", " + value))
    }

    // MARK: Macros

    private func macrosSection(summary: DailyNutritionSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HFSectionHeader("Dinh dưỡng")
            HFCard {
                VStack(spacing: 14) {
                    MacroBar(
                        label: "Đạm", tint: DS.blue,
                        consumed: summary.consumedProtein, target: summary.goal.protein
                    )
                    MacroBar(
                        label: "Tinh bột", tint: DS.orange,
                        consumed: summary.consumedCarbohydrates,
                        target: summary.goal.carbohydrates
                    )
                    MacroBar(
                        label: "Chất béo", tint: DS.green,
                        consumed: summary.consumedFat, target: summary.goal.fat
                    )

                    // **Drawn only when something today actually carries a
                    // figure.** The gateway returns no fibre, so a day of
                    // scanned meals has none — and a bar sitting at 0 g would
                    // tell the user they ate no fibre when nothing measured it.
                    if let fiber = summary.consumedFiber {
                        Divider().overlay(DS.borderSubtle)
                        MacroBar(
                            label: "Chất xơ", tint: DS.blue700,
                            consumed: fiber, target: summary.goal.fiber,
                            footnote: fiberFootnote(missing: summary.itemsMissingFiber)
                        )
                        // The bar merges into one element, so the footnote is
                        // part of its label rather than a text of its own —
                        // an identifier is the only way to name it.
                        .accessibilityIdentifier("macro.fiber")
                    }
                }
            }
        }
    }

    /// Says out loud that the figure above is a floor rather than a total.
    /// `nil` once everything logged today has been measured.
    private func fiberFootnote(missing: Int) -> String? {
        guard missing > 0 else { return nil }
        return L("\(missing) món chưa có số liệu chất xơ")
    }

    // MARK: Water

    /// `plan.md` Phase 5's optional water tracking.
    ///
    /// Its own card rather than a fourth bar in "Dinh dưỡng": water carries no
    /// energy, is logged by tapping rather than by eating, and is the only
    /// figure on this screen the user changes from the screen itself.
    private func waterSection(_ water: DailyWater) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HFSectionHeader("Nước")
            HFCard {
                VStack(alignment: .leading, spacing: DS.s3) {
                    (Text(AppNumber.int(water.consumed))
                        .hfStyle(HFType.cardMetric)
                        .foregroundStyle(DS.textStrong)
                        + Text(verbatim: " / \(AppNumber.int(water.target)) ml")
                        .hfStyle(HFType.rowValue)
                        .foregroundStyle(DS.textMuted))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isStaticText)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.trackBg)
                            Capsule().fill(DS.blue500)
                                .frame(width: geometry.size.width * water.fraction)
                        }
                    }
                    .frame(height: 7)
                    .accessibilityHidden(true)

                    // Undo sits with the two adds rather than up beside the
                    // figure. In the header row it was in an
                    // `HStack(alignment: .firstTextBaseline)` next to a 21pt
                    // metric, and its taps went nowhere at all: XCUITest
                    // reported a successful tap and the action never ran, so it
                    // behaved exactly like a button that was not wired up. Here
                    // it is laid out like the buttons that always worked.
                    HStack(spacing: DS.s2) {
                        ForEach(WaterServing.allCases, id: \.self) { serving in
                            waterButton(serving)
                        }
                        if water.mostRecent != nil {
                            Button {
                                Task { await model?.undoLastDrink() }
                            } label: {
                                Text("Hoàn tác")
                                    .hfStyle(HFType.rowLabel)
                                    .foregroundStyle(DS.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .background(
                                        DS.surfaceSunken,
                                        in: RoundedRectangle(
                                            cornerRadius: DS.rControl, style: .continuous
                                        )
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("water.undo")
                        }
                    }

                    if let message = model?.waterErrorMessage {
                        Text(verbatim: message)
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("water.error")
                    }
                }
            }
            // The figures merge into one element; the buttons keep their own.
            .accessibilityElement(children: .contain)
        }
    }

    private func waterButton(_ serving: WaterServing) -> some View {
        Button {
            Task { await model?.drink(serving) }
        } label: {
            Text(verbatim: serving.label)
                .hfStyle(HFType.rowLabel)
                .foregroundStyle(DS.blue700)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(DS.blue50, in: RoundedRectangle(cornerRadius: DS.rControl, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("water.add.\(Int(serving.millilitres))")
        .accessibilityLabel(Text(verbatim: L("Thêm \(AppNumber.int(serving.millilitres)) ml")))
    }

    // MARK: Meals

    private func mealsSection(summary: DailyNutritionSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HFSectionHeader("Bữa ăn")
            HFCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(MealType.allCases.enumerated()), id: \.element) { index, type in
                        let meals = summary.meals(of: type)
                        Button {
                            if meals.flatMap(\.items).isEmpty {
                                entryType = type
                            } else {
                                detailType = type
                            }
                        } label: {
                            MealRow(
                                type: type,
                                kcal: meals.reduce(0) { $0 + $1.calories },
                                foodNames: meals.flatMap(\.items).map(\.name)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("mealRow.\(type.rawValue)")

                        if index < MealType.allCases.count - 1 {
                            Rectangle()
                                .fill(DS.borderSubtle)
                                .frame(height: 1)
                                .padding(.leading, 62)
                        }
                    }
                }
            }
        }
    }

    // MARK: Apple Health

    @ViewBuilder
    private func healthSection(model: DashboardModel) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HFSectionHeader("Apple Health")

            if let health = model.health, !health.isEmpty {
                let columns = [GridItem(.flexible(), spacing: DS.s3),
                               GridItem(.flexible(), spacing: DS.s3)]
                LazyVGrid(columns: columns, spacing: DS.s3) {
                    HealthTile(
                        label: "Bước chân",
                        value: health.steps.map { AppNumber.int($0) }
                    )
                    HealthTile(
                        label: "Năng lượng",
                        value: health.activeEnergyKcal.map { "\(AppNumber.int($0)) kcal" }
                    )
                    HealthTile(
                        label: "Giấc ngủ",
                        value: health.sleepDuration.map { Self.sleepText($0) }
                    )
                    HealthTile(
                        label: "Cân nặng",
                        value: health.weightKg.map { "\(AppNumber.oneDecimal($0)) kg" }
                    )
                }
            } else {
                notConnectedCard
            }
        }
    }

    private var notConnectedCard: some View {
        Text("Kết nối Apple Health để thấy bước chân, năng lượng và giấc ngủ.")
            .hfStyle(HFType.body)
            .foregroundStyle(DS.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.s4)
            .background(
                RoundedMerge(radius: 14)
                    .strokeBorder(DS.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
    }

    // MARK: BMI

    private func bmiRow(bmi: BMI) -> some View {
        HFCard {
            HStack(alignment: .center, spacing: DS.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BMI \(AppNumber.oneDecimal(bmi.value))")
                        .hfStyle(HFType.rowLabel)
                        .foregroundStyle(DS.textStrong)
                    Text("Bối cảnh sức khỏe, không dùng để tính calo")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                }
                Spacer(minLength: DS.s2)
                // Once, in the badge — see the same change in onboarding's
                // result step.
                Text(verbatim: bmi.category.label)
                    .hfStyle(HFType.subLabelSemibold)
                    .foregroundStyle(DS.blue700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DS.blue50, in: Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "BMI \(AppNumber.oneDecimal(bmi.value)), \(bmi.category.label)"
            )
        }
    }

    /// "7h 32m" per §6.4.
    private static func sleepText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

/// `RoundedRectangle` that can be stroked as a border shape.
private struct RoundedMerge: InsettableShape {
    let radius: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> RoundedMerge {
        RoundedMerge(radius: radius, inset: inset + amount)
    }
}

private struct MacroBar: View {
    let label: LocalizedStringKey
    let tint: Color
    let consumed: Double
    let target: Double
    /// A qualification on the figure — currently only fibre's "N món chưa có
    /// số liệu", which is what stops a partial sum reading as a total.
    var footnote: String?

    private var fraction: Double {
        target > 0 ? min(consumed / target, 1) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            HStack(alignment: .firstTextBaseline) {
                HFLabel(label)
                Spacer(minLength: DS.s2)
                Text(AppNumber.int(consumed))
                    .hfStyle(HFType.rowValue)
                    .foregroundStyle(DS.textStrong)
                    + Text(" / \(AppNumber.int(target)) g")
                    .hfStyle(HFType.rowValue)
                    .foregroundStyle(DS.textMuted)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.neutral150)
                    Capsule().fill(tint).frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 7)

            if let footnote {
                Text(verbatim: footnote)
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(label) + Text(", \(AppNumber.int(consumed)) trên \(AppNumber.int(target)) gam")
                + Text(verbatim: footnote.map { ", " + $0 } ?? "")
        )
        // **Without this the bar is an `otherElement`, not a static text.**
        // A merged element with no trait is exposed as a plain container, so
        // VoiceOver announces it without saying it is text and
        // `app.staticTexts[…]` cannot find it — the rule CLAUDE.md records for
        // `DSValueRow`, which this component predates. It had been missing
        // since the bar was written; a fibre test asking for it by identifier
        // is what turned it up.
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct MealRow: View {
    let type: MealType
    let kcal: Double
    let foodNames: [String]

    private var detail: String {
        foodNames.isEmpty ? L("Chưa ghi") : foodNames.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: DS.s3) {
            Image(systemName: type.chipSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textBody)
                .frame(width: 34, height: 34)
                .background(type.chipColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(type.label)
                    .hfStyle(HFType.rowLabel)
                    .foregroundStyle(DS.textStrong)
                Text(detail)
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: DS.s2)

            Text(foodNames.isEmpty ? "—" : AppNumber.int(kcal))
                .hfStyle(HFType.rowValue)
                .foregroundStyle(foodNames.isEmpty ? DS.textSubtle : DS.textStrong)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.neutral300)
        }
        .padding(.horizontal, DS.s4)
        .frame(minHeight: 62)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(type.label), \(foodNames.isEmpty ? "chưa ghi" : AppNumber.int(kcal) + " kcal")")
    }
}

private struct HealthTile: View {
    let label: LocalizedStringKey
    let value: String?

    var body: some View {
        HFCard(padding: DS.s4, radius: 14) {
            VStack(alignment: .leading, spacing: DS.s1) {
                Text(value ?? "—")
                    .hfStyle(HFType.cardMetric)
                    .foregroundStyle(DS.textStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HFLabel(label)
            }
        }
        .accessibilityElement(children: .ignore)
        // Built as `Text` rather than a string: the label is a catalog key, and
        // only `Text` resolves one against the environment locale.
        .accessibilityLabel(
            Text(label) + Text(verbatim: ", ") + Text(value ?? L("chưa có dữ liệu"))
        )
    }
}
