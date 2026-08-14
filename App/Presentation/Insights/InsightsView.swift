import Domain
import SwiftUI

/// Insights — handoff §6.12.
///
/// Two of §6.12's four stat cells are absent: "% bữa ăn được ghi" has no
/// denominator (the app never learns how many meals a user meant to eat), and
/// "% AI cần sửa khẩu phần" is not recorded — `FoodItem` keeps the model's
/// confidence but not whether the user corrected the portion. Inventing either
/// number would be worse than leaving it out.
struct InsightsView: View {
    /// See `DashboardView.refreshID`.
    var refreshID: Int = 0

    @Environment(DependencyContainer.self) private var container
    @State private var model: InsightsModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s5) {
                if let model {
                    if let message = model.errorMessage {
                        GrayNote(verbatim: message)
                    } else {
                        calorieCard(model)
                        weightCard(model)
                        statGrid(model)
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
        // Hiding the nav bar leaves nothing masking the top inset, so the title
        // and cards scrolled up through the clock. Same fix as the dashboard.
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, DS.s2)
                .padding(.bottom, DS.s3)
                .background(DS.surfacePage)
        }
        .task(id: refreshID) {
            if model == nil { model = container.makeInsightsModel() }
            await model?.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("THỐNG KÊ · INSIGHTS")
                .hfStyle(HFType.eyebrow)
                .foregroundStyle(DS.textSubtle)
            Text("7 ngày qua")
                .font(.custom(DSFontName.extrabold, size: 29))
                .tracking(-0.725)
                .foregroundStyle(DS.textStrong)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Calories

    private func calorieCard(_ model: InsightsModel) -> some View {
        HFCard(radius: 18) {
            VStack(alignment: .leading, spacing: DS.s4) {
                HStack(alignment: .top, spacing: DS.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calo mỗi ngày")
                            .hfStyle(HFType.sectionHead)
                            .foregroundStyle(DS.textStrong)
                        Text(
                            model.dailyGoalCalories > 0
                                ? "vs mục tiêu \(VNNumber.int(model.dailyGoalCalories)) kcal"
                                : "Chưa có mục tiêu"
                        )
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                    }
                    Spacer(minLength: 0)
                    if model.hasCalorieData {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(VNNumber.int(model.averageCalories))
                                .font(.custom(DSFontName.extrabold, size: 20))
                                .tracking(-0.4)
                                .foregroundStyle(DS.textStrong)
                            Text("trung bình")
                                .hfStyle(HFType.subLabel)
                                .foregroundStyle(DS.textSubtle)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "Trung bình \(VNNumber.int(model.averageCalories)) kcal mỗi ngày"
                        )
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityIdentifier("insights.average")
                    }
                }

                if model.hasCalorieData {
                    calorieChart(model)
                } else {
                    GrayNote(text: "Chưa có bữa ăn nào trong 7 ngày qua.")
                }
            }
        }
    }

    /// §6.12: 132pt tall, 8pt gaps, `6 6 3 3` corners, a dashed goal line, and
    /// today's value printed above its bar.
    private func calorieChart(_ model: InsightsModel) -> some View {
        let barsHeight: CGFloat = 132
        let ceiling = model.chartCeiling

        return VStack(spacing: DS.s2) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(model.days) { day in
                    calorieBar(
                        day,
                        model: model,
                        height: barsHeight * CGFloat(min(day.calories / ceiling, 1))
                    )
                }
            }
            // Headroom so today's printed value is never clipped by a bar that
            // reaches the ceiling.
            .frame(height: barsHeight + 18, alignment: .bottom)
            .overlay(alignment: .bottom) {
                if model.dailyGoalCalories > 0 {
                    goalLine(offset: barsHeight * CGFloat(model.dailyGoalCalories / ceiling))
                }
            }

            HStack(spacing: 8) {
                ForEach(model.days) { day in
                    Text(dayLabel(day.date))
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(calorieChartSummary(model))
        .accessibilityAddTraits(.isStaticText)
    }

    private func calorieBar(_ day: InsightsModel.Day, model: InsightsModel, height: CGFloat)
        -> some View
    {
        let isToday = Calendar.current.isDateInToday(day.date)
        let isOver = model.dailyGoalCalories > 0 && day.calories > model.dailyGoalCalories
        // A day over goal reads red, matching the dashboard ring. Today still
        // wins on colour so "which bar is now" stays the first thing legible.
        let fill: Color = isToday ? (isOver ? DS.danger : DS.blue) : (isOver ? DS.danger.opacity(0.55) : DS.blue200)

        return VStack(spacing: 3) {
            if isToday && day.isLogged {
                Text(VNNumber.int(day.calories))
                    .font(.custom(DSFontName.bold, size: 11))
                    .foregroundStyle(DS.textStrong)
            }
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 3,
                bottomTrailingRadius: 3,
                topTrailingRadius: 6,
                style: .continuous
            )
            .fill(fill)
            // A logged day always shows something; an empty day shows nothing,
            // which is how the chart says "not recorded".
            .frame(height: day.isLogged ? max(height, 4) : 0)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private func goalLine(offset: CGFloat) -> some View {
        Rectangle()
            .fill(DS.neutral300)
            .frame(height: 1.5)
            .mask {
                // A dashed rule, drawn as a mask so the 1.5pt height is exact.
                Line().stroke(style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
            }
            .padding(.bottom, offset)
    }

    private func calorieChartSummary(_ model: InsightsModel) -> String {
        let days = model.days.filter(\.isLogged).map {
            "\(dayLabel($0.date)) \(VNNumber.int($0.calories)) kcal"
        }
        return "Calo mỗi ngày: " + days.joined(separator: ", ")
    }

    /// "T2"…"CN", and "Nay" for today (§6.12).
    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Nay" }
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 ? "CN" : "T\(weekday)"
    }

    // MARK: Weight

    private func weightCard(_ model: InsightsModel) -> some View {
        let series = model.weightSeries

        return HFCard(radius: 18) {
            VStack(alignment: .leading, spacing: DS.s4) {
                HStack(alignment: .top, spacing: DS.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cân nặng")
                            .hfStyle(HFType.sectionHead)
                            .foregroundStyle(DS.textStrong)
                        Text(weightSubtitle(model))
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.textSubtle)
                    }
                    Spacer(minLength: 0)
                    if let current = series.current {
                        Text("\(VNNumber.oneDecimal(current)) kg")
                            .font(.custom(DSFontName.extrabold, size: 20))
                            .tracking(-0.4)
                            .foregroundStyle(DS.textStrong)
                            .accessibilityLabel("Hiện tại \(VNNumber.oneDecimal(current)) kg")
                            .accessibilityIdentifier("insights.currentWeight")
                    }
                }

                if series.points.isEmpty {
                    GrayNote(text: "Chưa có cân nặng nào được ghi.")
                } else {
                    WeightChart(series: series)
                        .frame(height: 96)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(weightChartSummary(series))
                        .accessibilityAddTraits(.isStaticText)

                    HStack(spacing: 0) {
                        ForEach(0..<series.weekCount, id: \.self) { index in
                            Text(index == series.weekCount - 1 ? "Nay" : "T\(index + 1)")
                                .hfStyle(HFType.subLabel)
                                .foregroundStyle(DS.textSubtle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func weightSubtitle(_ model: InsightsModel) -> String {
        let weeks = "\(model.weightSeries.weekCount) tuần"
        guard let target = model.targetWeightKg else { return weeks }
        return "\(weeks) · mục tiêu \(VNNumber.oneDecimal(target)) kg"
    }

    private func weightChartSummary(_ series: WeightSeries) -> String {
        let values = series.points.map { "\(VNNumber.oneDecimal($0.kilograms)) kg" }
        return "Cân nặng theo tuần: " + values.joined(separator: ", ")
    }

    // MARK: Stats

    private func statGrid(_ model: InsightsModel) -> some View {
        HStack(spacing: DS.s3) {
            statCell(
                value: "\(model.daysWithinGoal)/\(InsightsModel.dayCount)",
                vi: "ngày trong mục tiêu",
                en: "days within goal",
                tint: DS.blue,
                identifier: "insights.daysWithinGoal"
            )
            statCell(
                value: weightChangeText(model.weightSeries),
                vi: "trong \(model.weightSeries.weekCount) tuần",
                en: "over \(model.weightSeries.weekCount) weeks",
                tint: DS.green,
                identifier: "insights.weightChange"
            )
        }
    }

    private func weightChangeText(_ series: WeightSeries) -> String {
        guard let change = series.change else { return "—" }
        // A minus sign, not a hyphen: this is a number, not a dash.
        let sign = change < 0 ? "−" : (change > 0 ? "+" : "±")
        return "\(sign)\(VNNumber.oneDecimal(abs(change))) kg"
    }

    private func statCell(
        value: String,
        vi: String,
        en: String,
        tint: Color,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.s1) {
            Text(value)
                .font(.custom(DSFontName.extrabold, size: 22))
                .tracking(-0.44)
                .foregroundStyle(tint)
            LabelPair(vi: vi, en: en)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.s4)
        .background(DS.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DS.borderSubtle, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(vi)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier(identifier)
    }
}

/// §6.12's 96pt polyline: 2.5pt green stroke with round joins over a
/// `green-100` fill.
private struct WeightChart: View {
    let series: WeightSeries

    var body: some View {
        GeometryReader { geometry in
            let points = positions(in: geometry.size)

            ZStack {
                if points.count >= 2 {
                    fillPath(points, height: geometry.size.height)
                        .fill(DS.green100)
                    linePath(points)
                        .stroke(
                            DS.green,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                }
                // Every measurement is marked, so a single weighing still reads
                // as data rather than an empty card.
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(DS.green)
                        .frame(width: 5, height: 5)
                        .position(point)
                }
            }
        }
    }

    private func positions(in size: CGSize) -> [CGPoint] {
        let values = series.points.map(\.kilograms)
        guard let lowest = values.min(), let highest = values.max() else { return [] }
        // A flat series would divide by zero; draw it down the middle instead.
        let span = highest - lowest
        let inset: CGFloat = 4

        // x is the *centre of the week's column*, matching how the T1…Nay labels
        // below are laid out — an `HStack` of equal-width cells. Spreading the
        // points edge-to-edge instead (weekIndex / (weekCount - 1)) put the first
        // and last markers a column-half away from their own labels, so the line
        // drifted visibly out of register with the axis.
        let columnWidth = size.width / CGFloat(max(series.weekCount, 1))

        return series.points.map { point in
            let x = columnWidth * (CGFloat(point.weekIndex) + 0.5)
            let ratio = span > 0 ? (point.kilograms - lowest) / span : 0.5
            // Heavier is higher on the chart, so the ratio inverts.
            let y = (size.height - inset * 2) * CGFloat(1 - ratio) + inset
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        return path
    }

    private func fillPath(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = linePath(points)
        if let last = points.last, let first = points.first {
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.addLine(to: CGPoint(x: first.x, y: height))
            path.closeSubpath()
        }
        return path
    }
}

/// A horizontal rule, used as the dash mask for the goal line.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}
