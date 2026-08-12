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
                    toast = "Đã lưu bữa ăn · \(VNNumber.int(savedCalories)) kcal"
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
                .padding(.top, DS.s1)
                .padding(.bottom, DS.s3)
                .background(DS.surfacePage)
        }
        .navigationDestination(item: $detailType) { type in
            MealDetailView(
                model: container.makeMealDetailModel(
                    type: type,
                    meals: summary.meals(of: type),
                    dailyGoalCalories: summary.goal.calories
                ),
                onAddMore: {
                    detailType = nil
                    entryType = type
                },
                onChanged: {
                    Task { await self.model?.load() }
                },
                onDeleted: {
                    toast = "Đã xoá bữa ăn"
                    Task { await self.model?.load() }
                }
            )
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DS.s1) {
                Text(VietnameseDate.headerText(for: Date()))
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
                    GrayNote(text: note)
                }
            }
        }
    }

    private func ringCentre(summary: DailyNutritionSummary) -> some View {
        let remaining = summary.budget.remaining
        let overBudget = remaining < 0

        return VStack(spacing: 2) {
            Text(VNNumber.int(abs(remaining)))
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
            Text(overBudget ? "over target" : "remaining")
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)
        }
        .padding(.horizontal, DS.s6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            overBudget
                ? "\(VNNumber.int(abs(remaining))) kcal vượt mục tiêu"
                : "\(VNNumber.int(abs(remaining))) kcal còn lại"
        )
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("hero.remaining")
    }

    private func statsRow(model: DashboardModel, summary: DailyNutritionSummary) -> some View {
        HStack(spacing: 0) {
            heroStat(
                value: VNNumber.int(summary.goal.calories),
                vi: "Mục tiêu", en: "Goal"
            )
            divider
            heroStat(
                value: VNNumber.int(summary.consumedCalories),
                vi: "Đã ăn", en: "Eaten"
            )
            divider
            heroStat(
                // "—" when Health isn't connected (§6.4).
                value: model.health?.activeEnergyKcal.map { VNNumber.int($0) } ?? "—",
                vi: "Vận động", en: "Activity"
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.borderSubtle)
            .frame(width: 1, height: 34)
    }

    private func heroStat(value: String, vi: String, en: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .hfStyle(HFType.statValue)
                .foregroundStyle(DS.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(vi)
                .hfStyle(HFType.subLabelSemibold)
                .foregroundStyle(DS.textMuted)
            Text(en)
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vi), \(value)")
    }

    // MARK: Macros

    private func macrosSection(summary: DailyNutritionSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HFSectionHeader(vi: "Dinh dưỡng", en: "Macros")
            HFCard {
                VStack(spacing: 14) {
                    MacroBar(
                        vi: "Đạm", en: "Protein", tint: DS.blue,
                        consumed: summary.consumedProtein, target: summary.goal.protein
                    )
                    MacroBar(
                        vi: "Tinh bột", en: "Carbs", tint: DS.orange,
                        consumed: summary.consumedCarbohydrates,
                        target: summary.goal.carbohydrates
                    )
                    MacroBar(
                        vi: "Chất béo", en: "Fat", tint: DS.green,
                        consumed: summary.consumedFat, target: summary.goal.fat
                    )
                }
            }
        }
    }

    // MARK: Meals

    private func mealsSection(summary: DailyNutritionSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HFSectionHeader(vi: "Bữa ăn", en: "Meals")
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
            HFSectionHeader(vi: "Apple Health", en: "Activity")

            if let health = model.health, !health.isEmpty {
                let columns = [GridItem(.flexible(), spacing: DS.s3),
                               GridItem(.flexible(), spacing: DS.s3)]
                LazyVGrid(columns: columns, spacing: DS.s3) {
                    HealthTile(
                        vi: "Bước chân", en: "Steps",
                        value: health.steps.map { VNNumber.int($0) }
                    )
                    HealthTile(
                        vi: "Năng lượng", en: "Energy",
                        value: health.activeEnergyKcal.map { "\(VNNumber.int($0)) kcal" }
                    )
                    HealthTile(
                        vi: "Giấc ngủ", en: "Sleep",
                        value: health.sleepDuration.map { Self.sleepText($0) }
                    )
                    HealthTile(
                        vi: "Cân nặng", en: "Weight",
                        value: health.weightKg.map { "\(VNNumber.oneDecimal($0)) kg" }
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
                    Text("BMI \(VNNumber.oneDecimal(bmi.value)) · \(bmi.category.vi)")
                        .hfStyle(HFType.rowLabel)
                        .foregroundStyle(DS.textStrong)
                    Text("Bối cảnh sức khỏe, không dùng để tính calo")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                }
                Spacer(minLength: DS.s2)
                Text(bmi.category.en)
                    .hfStyle(HFType.subLabelSemibold)
                    .foregroundStyle(DS.blue700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DS.blue50, in: Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "BMI \(VNNumber.oneDecimal(bmi.value)), \(bmi.category.vi), \(bmi.category.en)"
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
    let vi: String
    let en: String
    let tint: Color
    let consumed: Double
    let target: Double

    private var fraction: Double {
        target > 0 ? min(consumed / target, 1) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            HStack(alignment: .firstTextBaseline) {
                LabelPair(vi: vi, en: en)
                Spacer(minLength: DS.s2)
                Text(VNNumber.int(consumed))
                    .hfStyle(HFType.rowValue)
                    .foregroundStyle(DS.textStrong)
                    + Text(" / \(VNNumber.int(target)) g")
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
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(vi), \(en), \(VNNumber.int(consumed)) trên \(VNNumber.int(target)) gam"
        )
    }
}

private struct MealRow: View {
    let type: MealType
    let kcal: Double
    let foodNames: [String]

    private var detail: String {
        foodNames.isEmpty ? "Chưa ghi · not logged" : foodNames.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: DS.s3) {
            Image(systemName: type.chipSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textBody)
                .frame(width: 34, height: 34)
                .background(type.chipColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(type.vi)
                    .hfStyle(HFType.rowLabel)
                    .foregroundStyle(DS.textStrong)
                Text(detail)
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: DS.s2)

            Text(foodNames.isEmpty ? "—" : VNNumber.int(kcal))
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
        .accessibilityLabel("\(type.vi), \(foodNames.isEmpty ? "chưa ghi" : VNNumber.int(kcal) + " kcal")")
    }
}

private struct HealthTile: View {
    let vi: String
    let en: String
    let value: String?

    var body: some View {
        HFCard(padding: DS.s4, radius: 14) {
            VStack(alignment: .leading, spacing: DS.s1) {
                Text(value ?? "—")
                    .hfStyle(HFType.cardMetric)
                    .foregroundStyle(DS.textStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                LabelPair(vi: vi, en: en)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vi), \(value ?? "chưa có dữ liệu")")
    }
}
