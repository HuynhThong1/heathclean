import Domain
import SwiftUI

/// PROFILE_SPEC §0's first change: the identity row and the three figures are
/// **one card**, divided by rules.
///
/// It replaces three separate tinted blocks, and the reason is a colour rule
/// rather than a layout preference: the "kg còn lại" block was green, and §4
/// reserves green for growth and success. A number counting down to a target is
/// neither — it is a fact that is equally true whichever direction it moves.
/// After this, the only green on the screen is the privacy tick.
struct ProfileHeaderCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let goal: NutritionGoal
    let bodyLine: String?
    let bmi: BMI?
    let kilogramsToTarget: Double?
    let onEdit: () -> Void

    var body: some View {
        SettingsCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: 14) {
                identity
                Rectangle().fill(DS.borderSubtle).frame(height: 1)
                stats
            }
        }
    }

    // MARK: Identity

    private var identity: some View {
        HStack(spacing: 13) {
            // §6.13 of the handoff draws initials. Nothing in the app ever asks
            // for a name — onboarding collects body data only — so a generic
            // glyph is the honest version; invented initials would not be.
            Image(systemName: "person.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DS.blueOnSurface)
                .frame(width: 52, height: 52)
                .background(DS.chipOnBg, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hồ sơ của bạn")
                    .hfStyle(ProfileType.headerName)
                    .foregroundStyle(DS.textStrong)
                if let bodyLine {
                    Text(verbatim: bodyLine)
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textMuted)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)

            Spacer(minLength: DS.s2)

            Button(action: onEdit) {
                Text("Sửa")
                    .hfStyle(ProfileType.inlineAction)
                    .foregroundStyle(DS.blueOnSurface)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.edit")
            .accessibilityLabel("Sửa hồ sơ")
        }
        .frame(minHeight: 44)
    }

    // MARK: Three figures

    /// Three columns split by vertical rules, which is what §1's table
    /// specifies — and a `ViewThatFits` fallback, because three 19pt figures
    /// with their labels cannot share 358pt at an accessibility text size and
    /// the rules are the first thing that stops meaning anything when they
    /// overlap.
    private var stats: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                statColumn(cells[0], isFirst: true)
                statColumn(cells[1], isFirst: false)
                statColumn(cells[2], isFirst: false)
            }
            VStack(alignment: .leading, spacing: DS.s3) {
                ForEach(cells) { cell in
                    statCell(cell)
                }
            }
        }
    }

    private func statColumn(_ cell: StatCell, isFirst: Bool) -> some View {
        statCell(cell)
            .padding(.leading, isFirst ? 0 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                if !isFirst {
                    Rectangle().fill(DS.borderSubtle).frame(width: 1)
                }
            }
    }

    private func statCell(_ cell: StatCell) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: cell.value)
                .hfStyle(ProfileType.headerStat)
                .foregroundStyle(DS.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: cell.label)
                .hfStyle(ProfileType.headerStatLabel)
                .foregroundStyle(DS.textBody)
                .padding(.top, 3)
            // The second line is a genuine second fact where there is one — the
            // BMI's band — and absent otherwise. The reference page prints an
            // English translation here; that line went away with §4's bilingual
            // labels, see `HFLabel`.
            if let detail = cell.detail {
                Text(verbatim: detail)
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textMuted)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: cell.accessibilityLabel))
        .accessibilityAddTraits(.isStaticText)
    }

    private struct StatCell: Identifiable {
        let id: String
        let value: String
        let label: String
        var detail: String?
        let accessibilityLabel: String
    }

    private var cells: [StatCell] {
        let calories = AppNumber.int(goal.calories)
        let bmiValue = bmi.map { AppNumber.oneDecimal($0.value) } ?? "—"
        let remaining = kilogramsToTarget.map { AppNumber.oneDecimal($0) } ?? "—"

        return [
            StatCell(
                id: "calories",
                value: calories,
                label: L("kcal / ngày"),
                accessibilityLabel: L("Mục tiêu mỗi ngày \(calories) kcal")
            ),
            StatCell(
                id: "bmi",
                value: bmiValue,
                label: L("BMI"),
                detail: bmi?.category.label,
                accessibilityLabel: bmi.map { L("BMI \(bmiValue), \($0.category.label)") }
                    ?? L("BMI chưa có")
            ),
            StatCell(
                id: "toGoal",
                value: remaining,
                // "Không đặt" rather than a 0: no target set and a target
                // already reached are different things, and 0,0 kg would say
                // the second when it means the first.
                label: kilogramsToTarget == nil ? L("Chưa đặt mục tiêu") : L("kg còn lại"),
                accessibilityLabel: kilogramsToTarget == nil
                    ? L("Chưa đặt cân nặng mục tiêu")
                    : L("Còn \(remaining) kg tới mục tiêu")
            )
        ]
    }
}

// MARK: - Previews

#Preview("Header card · light") {
    ProfileHeaderCardGallery().preferredColorScheme(.light)
}

#Preview("Header card · dark") {
    ProfileHeaderCardGallery().preferredColorScheme(.dark)
}

#Preview("Header card · accessibility3") {
    ProfileHeaderCardGallery().environment(\.dynamicTypeSize, .accessibility3)
}

private struct ProfileHeaderCardGallery: View {
    private let profile = UserProfile(
        age: 26,
        heightCm: 171,
        weightKg: 98,
        biologicalSex: .male,
        activityLevel: .sedentary,
        goal: .lose,
        targetWeightKg: 85
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // `verbatim` throughout the previews: a literal written into a
                // `LocalizedStringKey` is extracted into the catalog whether or
                // not the screen ever draws it, so preview scaffolding would
                // both add keys to translate and keep dead ones alive.
                SectionLabel(verbatim: "TÔI")
                ProfileHeaderCard(
                    goal: CalculateCalorieGoalUseCase().execute(profile: profile),
                    bodyLine: "26 tuổi · 171 cm · 98 kg",
                    bmi: CalculateBMIUseCase().execute(profile: profile),
                    kilogramsToTarget: 13,
                    onEdit: {}
                )
                ProfileHeaderCard(
                    goal: CalculateCalorieGoalUseCase().execute(profile: profile),
                    bodyLine: "26 tuổi · 171 cm · 98 kg",
                    bmi: nil,
                    kilogramsToTarget: nil,
                    onEdit: {}
                )
                .padding(.top, DS.s3)
            }
            .padding(.horizontal, DS.s4)
        }
        .background(DS.surfacePage)
    }
}
