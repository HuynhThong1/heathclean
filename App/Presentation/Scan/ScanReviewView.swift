import Domain
import SwiftUI

/// AI review — handoff §6.8. The model's proposal, always correctable, never
/// saved until confirmed.
///
/// **It is also where a failed analysis lands**, with `ScanModel.analysisFailure`
/// set: the photo, a note saying the analysis did not come back, and an empty
/// list the user fills in by hand. §6.7's dark error screen is gone — its two
/// exits both threw the photo away, so a photo the gateway could not analyse
/// could not be logged at all, even though the person holding the phone knew
/// exactly what was on the plate. Everything below therefore reads
/// `analysisFailure` (or `RecognizedFood.isFromModel`) rather than assuming a
/// model contributed anything.
struct ScanReviewView: View {
    @Bindable var model: ScanModel
    let onRescan: () -> Void
    let onConfirmed: (Double) -> Void
    let onCancel: () -> Void

    /// Decoded once rather than in `body`: the 1,600px frame would otherwise be
    /// decoded again on every weight edit, every rename and every sheet dismissal.
    @State private var photo: UIImage?

    /// Leaving this screen throws the analysis away, so it is asked about first.
    ///
    /// Both ways out cost the same two things — the model's proposal and every
    /// correction made to it since — and neither can be undone: nothing is saved
    /// until "Xác nhận bữa ăn", so there is no meal to go back to. Rescanning also
    /// spends a second call against the daily quota, which is the reason
    /// `CapturedPhotoView` exists one screen earlier.
    private enum ExitIntent: String, Identifiable {
        case back, rescan
        var id: String { rawValue }
    }

    @State private var pendingExit: ExitIntent?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.s4) {
                    headerRow
                    if let failure = model.analysisFailure {
                        analysisFailureNote(failure)
                    } else {
                        explainerPill
                    }
                    photoPreview
                    itemList
                    addByHandButton
                    totalCard
                    if let reason = model.blockedReason {
                        DSFieldMessage(text: reason, isError: true)
                    }
                    if let saveError = model.saveError {
                        DSFieldMessage(text: saveError, isError: true)
                            .accessibilityIdentifier("scan.saveError")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, DS.s3)
                .padding(.bottom, DS.s6)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .background(DS.surfacePage)
        .task { photo = model.analyzedImage.flatMap(UIImage.init(data:)) }
        .sheet(item: portionBinding) { food in
            PortionEditorSheet(
                food: food,
                onChange: { model.updateWeight(of: food.id, to: $0) },
                onRename: { model.rename(food.id, to: $0) },
                onSupplyNutrition: { calories, protein, carbs, fat, fiber in
                    model.supplyNutrition(
                        for: food.id,
                        calories: calories,
                        protein: protein,
                        carbohydrates: carbs,
                        fat: fat,
                        fiber: fiber
                    )
                },
                onRemove: {
                    model.remove(food.id)
                    model.editingFoodID = nil
                },
                onDone: { model.editingFoodID = nil }
            )
            // Taller when the nutrition entry is showing, or its Dùng số này
            // button sits below the sheet.
            .presentationDetents([.height(food.isResolved ? 460 : 620)])
            .presentationCornerRadius(DS.rSheet)
        }
        .sheet(item: $pendingExit) { intent in
            // Wrapped rather than written as literals: `HFDestructiveConfirm`
            // takes `String`, so a literal here never reaches the catalog — the
            // trap `GrayNote` recorded. The component itself should take a
            // `LocalizedStringKey`; that is a wider change than this screen.
            HFDestructiveConfirm(
                title: intent == .back
                    ? (allFromModel ? L("Bỏ kết quả quét?") : L("Bỏ bữa ăn chưa lưu?"))
                    : L("Quét lại?"),
                message: message(for: intent),
                confirmLabel: intent == .back
                    ? L("Bỏ kết quả")
                    : L("Quét lại"),
                onConfirm: {
                    pendingExit = nil
                    leave(intent)
                },
                onCancel: { pendingExit = nil }
            )
        }
    }

    /// Asks only when there is something to lose.
    ///
    /// An empty list — a failed analysis nobody has typed into yet — has nothing
    /// to protect, and a confirmation over nothing is one people learn to tap
    /// through.
    private func requestExit(_ intent: ExitIntent) {
        guard !model.foods.isEmpty else {
            leave(intent)
            return
        }
        pendingExit = intent
    }

    private func leave(_ intent: ExitIntent) {
        switch intent {
        case .back: onCancel()
        case .rescan: onRescan()
        }
    }

    /// Names what is lost, and counts it. "Mọi thay đổi" is true of a plate the
    /// user has not touched as well, where the warning is only in the way.
    ///
    /// It does not say "AI nhận diện" unless everything on the list came from the
    /// model: after a failure the items are the user's own, and telling them the
    /// AI's results are about to be lost would be describing a different screen.
    private func message(for intent: ExitIntent) -> String {
        let count = model.foods.count
        let base = allFromModel
            ? L("Bữa ăn chưa được lưu. \(count) món AI nhận diện và mọi chỉnh sửa của bạn sẽ mất.")
            : L("Bữa ăn chưa được lưu. \(count) món trên màn hình sẽ mất.")
        guard intent == .rescan else { return base }
        return base + " " + L("Lần quét mới dùng thêm một lượt phân tích.")
    }

    /// Empty counts as "from the model" nowhere: the two callers both guard on a
    /// non-empty list first.
    private var allFromModel: Bool {
        model.foods.allSatisfy(\.isFromModel)
    }

    private var portionBinding: Binding<RecognizedFood?> {
        Binding(
            get: { model.editingFood },
            set: { model.editingFoodID = $0?.id }
        )
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .top, spacing: DS.s3) {
            HFBackChip { requestExit(.back) }
                .accessibilityIdentifier("scan.back")

            // Says what the screen is, which is no longer always the same thing:
            // after a failure there is no AI result to review.
            VStack(alignment: .leading, spacing: 1) {
                Text(model.analysisFailure == nil ? "Kết quả AI" : "Nhập bữa ăn")
                    .font(.custom(DSFontName.bold, size: 18))
                    .foregroundStyle(DS.textStrong)
                Text(
                    model.analysisFailure == nil
                        ? "AI PHÂN TÍCH · bạn xác nhận"
                        : "ẢNH ĐÃ CHỤP · bạn nhập số liệu"
                )
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
            }

            Spacer(minLength: DS.s2)

            // Styled inside the label and `.plain`, or the default style tints it
            // system blue instead of `DS.blue`; 44pt tall because §4 sets that
            // floor and this was an 18pt strip in the hardest corner to hit.
            Button { requestExit(.rescan) } label: {
                Text("Quét lại")
                    .font(.custom(DSFontName.semibold, size: 13))
                    .foregroundStyle(DS.blue)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("scan.rescan")
        }
    }

    private var explainerPill: some View {
        HStack(alignment: .top, spacing: DS.s2) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.blue700)
            Text("AI nhận diện món và ước lượng khẩu phần. Calo do cơ sở dữ liệu dinh dưỡng tính — hãy sửa khẩu phần nếu chưa đúng.")
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.blue700)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.blue50, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// What replaces §6.7's error screen: the reason, what can still be done, and
    /// — while the list is empty — the offer to spend another analysis on the
    /// photo already in hand.
    ///
    /// Orange rather than `DS.danger`: nothing has gone wrong with the user's
    /// day, one request did not come back, and §0.3's rule against scolding is
    /// the same rule that keeps the over-budget state grey.
    private func analysisFailureNote(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HStack(alignment: .top, spacing: DS.s2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.orange700)
                VStack(alignment: .leading, spacing: 3) {
                    // On the sentence, not on the card: an identifier on the
                    // container propagates down and would overwrite the retry
                    // button's own, the trap PROFILE_SPEC's segmented control
                    // paid for.
                    Text(verbatim: reason)
                        .font(.custom(DSFontName.semibold, size: 14))
                        .foregroundStyle(DS.orange700)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("scan.analysisFailed")
                    Text("Ảnh vẫn ở đây — nhập món bằng tay rồi lưu, bữa ăn sẽ giữ ảnh này.")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.orange700)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if model.canRetryAnalysis {
                Button {
                    Task { await model.retryAnalysis() }
                } label: {
                    Text("Thử phân tích lại ảnh này")
                        .font(.custom(DSFontName.semibold, size: 14))
                        .foregroundStyle(DS.orange700)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(
                            DS.surfaceCard,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("scan.retryAnalysis")
            }
        }
        .padding(DS.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.orange100, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Photo

    /// The picture the numbers below are about.
    ///
    /// §6.8 draws this as a 120pt strip and it is **square instead**, on purpose:
    /// every other place the app shows a meal photo is 1:1 — the §6.6 viewfinder,
    /// `CapturedPhotoView` one screen earlier, and History's `MealThumbnail`
    /// everywhere it appears. A strip here would crop the dish differently from
    /// the frame the user aimed and differently again from the thumbnail they see
    /// afterwards, so the same photo would read as three different pictures.
    ///
    /// The box is sized first and the image fills it from an overlay, for the
    /// reason `CapturedPhotoView` records: `.scaledToFill()` on the image itself
    /// leaves the height unconstrained and it grows until it owns the screen.
    ///
    /// Absent rather than a placeholder when there is nothing to show — a scan
    /// always has bytes, so an empty frame would only ever be a decode failure,
    /// and the items are what this screen is for.
    @ViewBuilder
    private var photoPreview: some View {
        if let photo {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement()
                .accessibilityLabel("Ảnh bữa ăn vừa quét")
                // Without the trait a hand-declared element is exposed as an
                // `otherElement`, and `app.images[…]` will not find it — the same
                // trap `DSValueRow` records for `.isStaticText`.
                .accessibilityAddTraits(.isImage)
                .accessibilityIdentifier("scan.photo")
        }
    }

    // MARK: Items

    private var itemList: some View {
        VStack(spacing: 10) {
            ForEach(model.foods) { food in
                Button {
                    model.editingFoodID = food.id
                } label: {
                    ScanItemCard(food: food)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "scan.item.\(food.hasName ? food.name : food.id.uuidString)"
                )
            }
        }
    }

    /// The only way anything gets onto the list after a failure — and it is drawn
    /// on a successful review too, because a model that reads three dishes off a
    /// plate of four leaves the fourth exactly as unreachable. §4's "always
    /// correctable" covers what was missed as well as what was wrong.
    private var addByHandButton: some View {
        Button { model.addFoodByHand() } label: {
            Label("Thêm món bằng tay", systemImage: "plus")
                .font(.custom(DSFontName.semibold, size: 15))
                .foregroundStyle(DS.blue)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                        .strokeBorder(DS.borderDefault, lineWidth: 1.5)
                }
                // A stroke-only overlay does not hit-test where nothing is
                // drawn, so without this the empty thirds either side of the
                // label are dead space on a 52pt control.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scan.addByHand")
    }

    private var totalCard: some View {
        HFCard(padding: DS.s5, radius: 14) {
            VStack(alignment: .leading, spacing: DS.s3) {
                // Nothing is being estimated when the figures were typed in.
                Text(model.analysisFailure == nil ? "TỔNG ƯỚC TÍNH" : "TỔNG BỮA ĂN")
                    .hfStyle(HFType.eyebrow)
                    .foregroundStyle(DS.textSubtle)

                Text("\(AppNumber.int(model.result?.totalCalories ?? 0)) kcal")
                    .font(.custom(DSFontName.extrabold, size: 30))
                    .tracking(-0.6)
                    .foregroundStyle(DS.blue)
                    .accessibilityIdentifier("scan.total")

                HStack(spacing: DS.s2) {
                    MacroChip(
                        vi: "Đạm", grams: model.result?.totalProtein ?? 0,
                        background: DS.blue50, foreground: DS.blue700
                    )
                    MacroChip(
                        vi: "Tinh bột", grams: model.result?.totalCarbohydrates ?? 0,
                        background: DS.orange100, foreground: DS.orange700
                    )
                    MacroChip(
                        vi: "Chất béo", grams: model.result?.totalFat ?? 0,
                        background: DS.green100, foreground: DS.green700
                    )
                }

                Text(sourceFootnote)
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("scan.sources")
            }
        }
    }

    /// §6.8 asks the total card to name where the numbers came from, and this
    /// **said "CSDL món Việt" whatever happened** — including on a plate where
    /// nothing resolved at all and the table contributed nothing. It is now read
    /// off the items.
    ///
    /// Worth naming per source rather than in general: one meal can now mix a
    /// dish computed from a USDA recipe with a row that is still asserted, and
    /// those are not equally trustworthy. The per-item lines say which is which;
    /// this says what the plate as a whole rests on.
    private var sourceFootnote: String {
        // No model contributed anything, so there is no provider to name and no
        // database to credit — saying "CSDL món Việt · mock" here would be
        // attributing the user's own typing to a scan that never returned.
        if model.analysisFailure != nil {
            return L("Không có kết quả AI · số liệu do bạn nhập")
        }

        let provider = model.result?.provider ?? "—"
        let resolved = model.foods.filter(\.isResolved)

        guard !resolved.isEmpty else {
            return L("Chưa món nào tra được dinh dưỡng · \(provider)")
        }

        var seen = Set<String>()
        let names = resolved
            .compactMap { NutritionSourceCopy.name(for: $0.nutritionSource) }
            .filter { seen.insert($0).inserted }

        // Resolved but unattributed is its own case, not the empty one: the
        // development provider returns nutrition without naming a source, and
        // reporting that as "nothing resolved" would be false about a plate
        // that is showing real figures.
        guard !names.isEmpty else {
            return L("Nguồn: không rõ · \(provider)")
        }
        return L("Nguồn: \(names.joined(separator: ", ")) · \(provider)")
    }

    private var bottomBar: some View {
        HStack(spacing: DS.s3) {
            // §6.8's 104pt meal-type button. It was inert text captioned
            // "bữa ăn", which named the value without offering to change it.
            Button { model.cycleMealType() } label: {
                VStack(spacing: 1) {
                    Text(model.type.label)
                        .font(.custom(DSFontName.bold, size: 13))
                        .foregroundStyle(DS.textStrong)
                    Text("đổi bữa")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.blue)
                }
                .frame(width: 104)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("scan.mealType")
            .accessibilityLabel("Bữa ăn: \(model.type.label). Chạm để đổi bữa.")

            Button("Xác nhận bữa ăn") {
                Task {
                    if let calories = await model.confirm() { onConfirmed(calories) }
                }
            }
            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
            .disabled(!model.canConfirm)
            .accessibilityIdentifier("scan.confirm")
        }
        .padding(.horizontal, 20)
        .padding(.top, DS.s3)
        .padding(.bottom, DS.s2)
        .background(DS.surfaceCard)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.borderSubtle).frame(height: 1)
        }
    }
}

// MARK: - Item card

private struct ScanItemCard: View {
    let food: RecognizedFood

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    // A food the user just added has no name yet, and a card with
                    // a blank first line reads as a rendering fault rather than as
                    // something waiting to be filled in.
                    (food.hasName ? Text(verbatim: food.name) : Text("Chưa có tên"))
                        .font(.custom(DSFontName.bold, size: 15))
                        .tracking(-0.15)
                        .foregroundStyle(food.hasName ? DS.textStrong : DS.textMuted)
                    if let nameEn = food.nameEn {
                        Text(nameEn)
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.textSubtle)
                    }
                }
                Spacer(minLength: DS.s2)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(AppNumber.int(food.calories))
                        .font(.custom(DSFontName.bold, size: 16))
                        .foregroundStyle(DS.textStrong)
                    Text("kcal")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                }
            }

            HStack(spacing: DS.s2) {
                Text("\(AppNumber.int(food.weightGrams)) g")
                    .font(.custom(DSFontName.semibold, size: 12.5))
                    .foregroundStyle(DS.textBody)
                    .padding(.horizontal, DS.s2)
                    .padding(.vertical, 3)
                    .background(DS.surfaceSunken, in: Capsule())

                // Absent for a hand-typed food: there is no estimate, so any
                // percentage here would be invented.
                if food.isFromModel {
                    confidenceBadge
                }

                Spacer(minLength: DS.s1)

                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.neutral400)
            }

            if food.isResolved {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đ \(AppNumber.int(food.protein)) · TB \(AppNumber.int(food.carbohydrates)) · B \(AppNumber.int(food.fat))")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                    if let source = nutritionSourceLabel {
                        Text(source)
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(food.nutritionIsReference ? DS.orange700 : DS.textSubtle)
                    }
                }
            } else {
                // Points at the portion editor, where nutrition can be entered.
                // It used to say "sửa tên", which does not resolve anything. A
                // hand-typed food is not missing from the database — nobody
                // looked it up — so it gets its own sentence.
                Text(
                    food.isFromModel
                        ? "Chưa có trong cơ sở dữ liệu — mở món này để nhập dinh dưỡng."
                        : "Mở món này để nhập khối lượng và calo."
                )
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.orange700)
            }
        }
        .padding(DS.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surfaceCard)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    food.isLowConfidence || !food.isResolved ? DS.orange300 : DS.borderSubtle,
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Ends with the confidence only when there is one. A hand-typed food read
    /// out as "Tin cậy 0%" would be VoiceOver stating the opposite of the truth.
    ///
    /// Two whole sentences rather than one built by concatenation, so each is a
    /// catalog key a translator can order for their own language.
    private var accessibilityLabel: Text {
        let name = food.hasName ? food.name : L("Chưa có tên")
        let grams = AppNumber.int(food.weightGrams)
        let calories = AppNumber.int(food.calories)
        guard let confidenceText else {
            return Text("\(name), \(grams) gam, \(calories) kcal")
        }
        return Text("\(name), \(grams) gam, \(calories) kcal, \(confidenceText)")
    }

    private var confidenceText: String? {
        guard let confidence = food.confidence else { return nil }
        let percent = Int((confidence * 100).rounded())
        return food.isLowConfidence ? L("Nên kiểm tra \(percent)%") : L("Tin cậy \(percent)%")
    }

    private var nutritionSourceLabel: String? {
        NutritionSourceCopy.name(for: food.nutritionSource).map {
            L("Nguồn: \($0)")
        }
    }

    private var confidenceBadge: some View {
        Text(verbatim: confidenceText ?? "")
            .font(.custom(DSFontName.semibold, size: 11.5))
            .foregroundStyle(badgeForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeBackground, in: Capsule())
    }

    private var badgeBackground: Color {
        if food.isLowConfidence { return DS.orange100 }
        return (food.confidence ?? 0) >= 0.90 ? DS.green100 : DS.blue50
    }

    private var badgeForeground: Color {
        if food.isLowConfidence { return DS.orange700 }
        return (food.confidence ?? 0) >= 0.90 ? DS.green700 : DS.blue700
    }
}
