import SwiftUI

/// A day's calories against that day's target, as one 8pt bar with a mark where
/// the target sits (HISTORY_SPEC §2).
///
/// **The mark is the whole point.** A plain progress bar clipped at 100% can only
/// say "at or past the target"; this says how far, in either direction, without
/// ever needing a second colour for "bad" — over budget is `DS.overBudget`, a
/// neutral grey, per §0.3.
///
/// The scale leaves 12% of headroom above whichever of the two is larger, so a
/// day that lands exactly on target still has space to its right and the mark
/// never touches the end cap — where it would read as part of the frame rather
/// than as a position on it.
struct HistoryDeviationBar: View {
    let calories: Double
    /// 0 when the profile has not loaded, or before onboarding set one. The bar
    /// then draws the day's calories full-width with no mark: there is nothing to
    /// compare against, and inventing a target would be worse than showing none.
    let goalCalories: Double
    /// 8 in a day card, 10 in the day panel (§6).
    var height: CGFloat = 8

    private var hasGoal: Bool { goalCalories > 0 }

    private var maxValue: Double {
        max(max(calories, goalCalories), 1) * 1.12
    }

    private var fillFraction: Double {
        min(max(calories / maxValue, 0), 1)
    }

    private var goalFraction: Double {
        min(max(goalCalories / maxValue, 0), 1)
    }

    /// Over target is grey, at or under is brand blue (§3).
    private var fillColor: Color {
        hasGoal && calories > goalCalories ? DS.overBudget : DS.blue
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(DS.trackBg)
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(fillColor)
                    .frame(width: width * fillFraction)
                if hasGoal {
                    // Square, not a capsule: it is a tick on a scale, and rounding
                    // 1.5pt turns it into a smudge.
                    Rectangle()
                        .fill(DS.axis)
                        .frame(width: 1.5)
                        // Centred on the target rather than starting at it, so the
                        // mark means the value and not "just after" it.
                        .offset(x: max(width * goalFraction - 0.75, 0))
                }
            }
        }
        .frame(height: height)
        // Everything it shows is in the card's combined label already (§7).
        .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Deviation bar") {
        VStack(alignment: .leading, spacing: DS.s5) {
            ForEach(
                [
                    ("Dưới mục tiêu", 1_398.0, 1_900.0),
                    ("Gần mục tiêu", 1_681.0, 1_900.0),
                    ("Đạt mục tiêu", 1_905.0, 1_900.0),
                    ("Vượt mục tiêu", 2_080.0, 1_900.0),
                    ("Vượt rất nhiều", 3_400.0, 1_900.0),
                    ("Chưa có mục tiêu", 1_681.0, 0.0),
                ],
                id: \.0
            ) { label, calories, goal in
                VStack(alignment: .leading, spacing: DS.s2) {
                    Text(label)
                        .font(.custom(DSFontName.semibold, size: 11.5))
                        .foregroundStyle(DS.textMuted)
                    HistoryDeviationBar(calories: calories, goalCalories: goal)
                }
            }
            HistoryDeviationBar(calories: 1_681, goalCalories: 1_900, height: 10)
        }
        .padding(DS.s5)
        .background(DS.surfaceCard)
    }
#endif
