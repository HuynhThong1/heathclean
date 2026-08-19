# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build            # compiles the Domain library
swift test             # 124 Domain tests (swift-testing) — fast, no simulator

xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # + 40 UI tests
```

```bash
Scripts/run-on-device.sh      # build + install + launch on a paired iPhone
```

That script exists because three things have to be passed every time and none of
them fails loudly: `GATEWAY_URL` (unset → the mock provider, so the scan "works"
and never reaches a model), `GATEWAY_API_KEY` (unset → 401 from a deployed
gateway) and `-allowProvisioningUpdates` (without it a free Personal Team build
fails at signing). It takes the key from the environment or from the gateway
checkout's `.env`, never from a tracked file, and prints back what the built
`Info.plist` actually ended up with — a build setting that failed to substitute
leaves the literal `$(GATEWAY_URL)` behind, which is worth seeing.

Run one Domain test: `swift test --filter "macros re-sum"` (matches the `@Test`
display name). Run one UI test:
`-only-testing:HeathFirstUITests/Phase1FlowTests/testLoggingAMealMovesTheDashboard`.

`xcodebuild` output is enormous — redirect to a file and grep, rather than piping
through `head`, which can kill the build with SIGPIPE (exit 137).

Prefer `swift test` while working on `Sources/Domain/`; it needs no simulator and
runs in well under a second. Reach for `xcodebuild` only when `App/` changes.

## Architecture

Clean Architecture with the dependency rule enforced by the module boundary rather
than by convention:

```
Sources/Domain/    SwiftPM library — pure Swift, imports only stdlib + Foundation
Tests/DomainTests/ swift-testing suites for the whole Domain layer
App/               iOS app target — SwiftData + SwiftUI, depends on Domain
AppUITests/        XCUITest walkthrough of the Phase 1 flow
```

`Domain` must never import SwiftUI, SwiftData, HealthKit, CoreML, or AVFoundation.
Because it is a separate module, a violation is a compile error, not a review catch.
Keep it that way.

`HeathFirst.xcodeproj` was hand-written (no XcodeGen/Tuist here) and uses
`PBXFileSystemSynchronizedRootGroup`, so **new files under `App/` and `AppUITests/`
are picked up automatically** — do not add file references. It consumes the root
package via an `XCLocalSwiftPackageReference` with `relativePath = .`, which works
even though project and package share a directory.

### Data flow

SwiftUI view → `@Observable` model (`App/Presentation/*/`) → use case
(`Sources/Domain/UseCases/`) → repository protocol
(`Sources/Domain/Repositories/`) → `@ModelActor` implementation
(`App/Data/Local/SwiftData/`).

`@Model` classes exist only in the Data layer and convert to Domain structs at the
repository boundary via `entity.meal` / `entity.profile` style computed properties.
SwiftData types never travel upward. `DependencyContainer` is the single place
protocols are bound to implementations and models are constructed; its `init` is
`nonisolated` so it can be built in a stored-property initializer.

### Calorie model — the non-obvious parts

`CalculateCalorieGoalUseCase` derives everything from age, height, weight, sex,
activity and goal. BMI is deliberately **not** an input; it is health context only.

- BMR is Mifflin-St Jeor. An unspecified or `preferNotToSay` sex uses −78, the
  midpoint of the male (+5) and female (−161) constants.
- Floor: `max(adjusted, max(BMR, 1200))`. A deficit never prescribes below the
  user's own basal rate. **This visibly weakens the deficit for sedentary users**
  (reference profile gets 1780 kcal instead of 1636) and is intentional; the
  "a deficit never drops below the user's own basal rate" test pins it.
- Macros: protein 1.8 g/kg when losing else 1.6 g/kg, fat 25% of energy,
  carbohydrates take the remainder. They re-sum to the calorie target exactly.

Warning thresholds (`EvaluateCalorieBudgetUseCase`) are boundary-sensitive:
`<0.70 normal`, `≥0.70 informUser`, `≥0.90 nearTarget`, `≥1.00 reached`,
`>1.00 exceeded`. Message copy stays neutral and informative by design — `plan.md`
§18 explicitly rules out instructing the user whether to eat.

### Fibre and water (Phase 5)

Two more targets come out of the same use case, and **neither touches the energy
arithmetic**: fibre is a component of `carbohydrates` and is already counted
there, water has no energy at all. `macrosReSum` still holds, and
`FiberAndWaterTests` restates it at the one place fibre could have broken it.

- **Fibre: 14 g per 1.000 kcal** — the US DRI rule (IOM 2005), used instead of a
  flat 25/38 g so it scales with the target the app already derived.
- **Water: 35 ml per kg of body weight, floored at 1.500 ml.** This one is a
  **rule of thumb, not a sourced reference value**, and is flagged in code the
  way the 88-row nutrition table is: the published references (EFSA, D-A-CH) give
  flat *total* water figures that include what comes from food, which is not what
  this app can measure. Replace it if a sourced drinking-water value is adopted.

#### `FoodItem.fiber` is optional, and that is the whole design

**The gateway contract (`plan.md` §25) has no fibre field**, so a scan can never
supply one. A `Double` defaulting to `0` would therefore tell every user who logs
by scanning that they ate no fibre — the "switch that schedules nothing" mistake
with a number attached. So `nil` and `0` are different facts and every reader
keeps them apart:

- `Meal.knownFiber` sums only what is known; `Meal.itemsMissingFiber` is what says
  whether that sum is a total or a floor.
- `DailyNutritionSummary.consumedFiber` is **`nil`** for a day nothing measured,
  and the dashboard draws no bar at all rather than an empty one.
- When some of the day is measured and some is not, the bar carries "N món chưa
  có số liệu chất xơ" — otherwise a partial sum reads as a total.
- Manual entry and the portion editor's nutrition box are the two places a
  figure gets typed, both through blank-means-`nil` fields
  (`HFOptionalNumericField`, and `fiberText` in `PortionEditorSheet`). They show
  "—" rather than a 0 waiting to be corrected, because most packaging does not
  print fibre and a required field would make people type a zero that is not
  true.

**The wire is built and waiting.** `AnalyzeResponse.Item.fiber` decodes an
optional `fiber`, `RecognizedFood.fiber` carries it, `scaled(toWeightGrams:)`
scales it, `resolved(…)` accepts it, and `foodItem` saves it — so the gateway
can start sending the field with **no client release as a prerequisite**. That
is the whole reason it is `Optional` on the DTO rather than defaulted: a
non-optional would fail the entire response the moment a gateway build did not
send it, which would mean the client could not talk to today's gateway.

**Unverified: the decode itself.** Everything from `RecognizedFood` inwards is
covered by `FiberAndWaterTests`, but no gateway sends `fiber`, so no real
payload has ever carried the field through `AnalyzeResponse`. The first gateway
build that emits it is also the first test of that one line.

What is missing is the *data*: `/v1/meals/analyze` has no `fiber` field yet
because the nutrition table behind it has no fibre column. USDA FDC carries it
(nutrient 1079, *Fiber, total dietary*) and Open Food Facts has `fiber_100g`;
the 88-row local table does not — and since that table is already slated for
replacement, adding a column to it would be work thrown away twice.

`MockFoodRecognitionRepository` gives **two of its four foods** a fibre figure
and leaves two without, on purpose: a mock that filled in all four would
exercise a state the app has never been in and never the mixed one, where the
day's total is a floor and has to say so.

#### Water is a log, not a food

`WaterEntry` / `WaterRepository` beside the day, the same shape `WeightEntry`
takes beside the profile. It is deliberately **not** a `FoodItem`: it carries no
energy and is not part of a meal, and putting it in one would drag it into
`Meal.calories`, the history bar, the budget engine and §22's rates, each of
which would then need to learn to skip it.

- Millilitres, never glasses — a glass is not a unit, and two screens disagreeing
  about how big one is would make the total meaningless. `WaterServing` names the
  sizes (250 / 500) in Domain because *how much a tap is worth* is a product
  decision; only the wording is in `DisplayCopy`.
- The card **re-reads the store after every tap** rather than adding to a local
  total: a figure that moved before the write landed would be inventing one.
- Undo is a first-class action, because water is the only figure in the app
  logged by tapping rather than typing, and a quick-add that cannot be taken back
  is one people stop trusting. A failed undo now *says so* — see below.
- `DailyWater.remaining` never goes negative. Passing a rule-of-thumb figure is
  not a finding, and §0.3's rule against scolding applies here with more force
  than it does to calories.

#### Two traps this cost

- **`MacroBar` was an `otherElement`, and had been since it was written.** It
  merges its children with `.accessibilityElement(children: .ignore)` and a
  composed label but never claimed `.isStaticText`, so VoiceOver announced it as
  a plain container and `app.staticTexts[…]` could not find it — exactly what
  `DSValueRow`'s note in the design-system section warns about, in a component
  that predates it. A fibre test asking for the bar by identifier is what turned
  it up.
- **A button in an `HStack(alignment: .firstTextBaseline)` beside a 21pt metric
  never fired.** XCUITest reported a successful tap on it and the action did not
  run — indistinguishable from a control that was never wired up, and it survived
  a rename of the delete predicate and a rewrite of the repository fetch before a
  probe in the model showed the closure was simply never entered. Moving "Hoàn
  tác" down into the row with the two quick-adds, laid out like the buttons that
  always worked, fixed it. **If a button reports taps but does nothing, suspect
  the layout around it before the code inside it.**

### Testing conventions

- Use `expectClose` for every `Double` (`Tests/DomainTests/Support.swift`); plain
  `#expect(a == b)` is for exact types only. Separate names on purpose, so a float
  can never silently take the exact path.
- `makeProfile()` defaults to male, 80 kg, 180 cm, 30 y → BMR exactly 1780, which
  most expected values assume. `referenceDate` is a fixed instant; never introduce
  `Date()` into a test.
- UI tests launch with `-uiTesting`, which makes `DependencyContainer` use an
  in-memory store so every run starts at onboarding.
- Query UI elements by `accessibilityIdentifier`, never by label: `LabeledContent`
  merges label and value into one element ("Breakfast, 0 kcal"). Identifiers follow
  `mealRow.<rawValue>` and `field.<name>`.
- Numeric `TextField`s report `value` as an `Int`, and tapping puts the caret at the
  **start** — use `doubleTap()` to select before typing, or digits merge with the
  existing value.
- Totals render with locale grouping ("2.378"), so build expected strings with
  `.formatted()` rather than hardcoding separators.

### HealthKit (Phase 2)

`HealthRepository` (Domain protocol) → `HealthKitHealthRepository`
(`App/Data/HealthKit/`), an actor because `HKHealthStore` is not `Sendable`.

- **A denied read is indistinguishable from no data** — HealthKit returns an
  empty result either way, deliberately, so an app cannot detect that a user
  declined. Hence every field on `HealthSnapshot` is optional, per-type read
  failures are swallowed, and the protocol has no `authorizationStatus`. One
  unreadable type must never cost the others (`plan.md` §14).
- Health never fails the dashboard: `loadHealth()` is a separate step and its
  errors are dropped, because meals and targets must render regardless.
- `NSPredicate` is not `Sendable`, so queries take `Date` bounds and build their
  own predicate — sharing one across `async let` children is a compile error.
- Sleep sums only the `asleep*` categories; `inBed` overlaps them and would
  double count.
- Two build settings make this work and are easy to lose:
  `CODE_SIGN_ENTITLEMENTS = Config/HeathFirst.entitlements` and
  `NSHealthShareUsageDescription` in `Config/Info.plist`. The app reads only —
  there is no `NSHealthUpdateUsageDescription` and `toShare` is empty.
- **The HealthKit entitlement is currently taken out**, so that a free Apple ID
  (Personal Team) can provision a device build for camera testing — free
  provisioning does not grant HealthKit, and it fails at provisioning rather
  than at compile time. The *build setting* is untouched; only the keys were
  removed, and `Config/HeathFirst.entitlements` carries the exact text to put
  back. Health reads therefore fail on device and onboarding says "Apple Health
  hiện không khả dụng" — the error path, not a crash. **Restore the keys before
  shipping or as soon as a paid account is used.**
- Checking embedded entitlements on a simulator build is misleading:
  `HeathFirst.app.xcent` is empty (no provisioning profile configured), while
  `HeathFirst.app-Simulated.xcent` is the one actually used and does carry
  `com.apple.developer.healthkit`. A device build needs a profile with the
  HealthKit capability.
- **Unverified:** the Activity section rendering real values. The simulator has
  no health data and the app requests no write access, so only the authorization
  path has been exercised end to end. Observer queries and background delivery
  are explicitly Phase 2 "later" work and are not implemented.

### Design system

`App/Presentation/DesignSystem/` is a hand port of the **FPT IS Design System**
(Claude Design project `77c3dd08-7139-46b4-9df4-1a11e3ad2130`). Claude Design
emits React + CSS, so nothing is generated — tokens were transcribed and
components re-implemented from their `.jsx`/`.d.ts` specs.

- `DSPalette` holds the raw ramps verbatim and is **absolute** — never varies by
  appearance. `DSColor` is the semantic layer and is what app code should use.
- **The dark palette is invented.** The source design system is light-only; every
  dark value in `DSColor` was derived here and is documented in that file's
  header. Replace it wholesale if the brand team ever publishes real values.
- Type steps carry `relativeTo:` so Dynamic Type still scales them; the 64pt and
  52pt display steps are dropped as unusable on phone.
- Web-only concepts are deliberately absent: hover states (`:hover` became the
  pressed state), focus rings, and `--container-max`.
- The brand font is bundled in `App/Resources/Fonts/` and registered through
  `Config/Info.plist`. That plist must stay **outside** `App/` — inside the
  file-system-synchronized group it gets copied as a resource *and* generated,
  which fails the build with "Multiple commands produce Info.plist".
- Navigation titles need `DSAppearance.apply()` (UIKit proxy); `navigationTitle`
  ignores `.font`.

When adding a label/value row, use `DSValueRow` rather than `LabeledContent`.
`LabeledContent` merges its two sides into one accessibility element only with a
plain string label inside a `Form`/`List` — with styled labels or inside a card
it splits into two, which both hurts VoiceOver and breaks UI tests that match
strings like `"Protein, 112 g"`. `DSValueRow` and `DSStatBlock` declare the
merge explicitly, including `.accessibilityAddTraits(.isStaticText)` — without
that trait a combined element is exposed as an `otherElement` and
`app.staticTexts[…]` will not find it.

### Style a Button *inside* its label, never around it

```swift
// Wrong — the tap area stays where the glyphs are drawn.
Button("Xoá món này") { … }
    .frame(maxWidth: .infinity).frame(height: 52).background(…)

// Right.
Button { … } label: {
    Text("Xoá món này")
        .frame(maxWidth: .infinity).frame(minHeight: 52).background(…)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
```

Modifiers outside a `Button` dress a box the button does not own, so a 52pt-tall
full-width control answers only on its text. `.buttonStyle(.plain)` matters for a
second reason: the default borderless style tints `configuration.label` from the
inside, which beats an outer `.foregroundStyle` — that is how §6.10's quiet grey
delete action ended up drawing in system accent blue.

**This was written three times in this codebase before landing here**, twice after
being fixed elsewhere with a comment explaining it. A comment at the fix site did
not stop the next occurrence; this is the place that might.

### Sheets need `presentationBackground`, not `.background`

A `presentationDetents` height taller than the content, with
`.background(DS.surfaceCard)` on the content, leaves the unused height showing the
sheet's own backing. In light mode that is near-white and invisible; in dark mode
it is a black band above and below the content. Colour the sheet —
`.presentationBackground(DS.surfaceCard)`.

**`presentationDragIndicator(.visible)` takes no space in the layout.** It is
drawn by the presentation controller inside the sheet's own top ~10pt, over
whatever the content puts there — so the day panel's 8pt of top padding printed
the date across the grabber. A sheet that shows the indicator needs about 24pt
above its first line. `HistoryDayPanelSheet` is the only one in the app that
shows it.

**A fixed height is the deeper problem, and `HFDestructiveConfirm` shows what it
takes to size a sheet to its content.** Three things, all needed:

- `.fixedSize(horizontal: false, vertical: true)`, or the sheet stretches the
  stack to the detent and the measurement below reads back the height it just
  set — the sheet then never shrinks.
- The measurement goes in a **`.background`**, not an overlay: `Color.clear` takes
  hits in SwiftUI, so an overlay eats the buttons' taps. `onGeometryChange` would
  be tidier but is iOS 18 and the target is 17.
- **The sheet does not inset its content for the home indicator.** Its own bottom
  padding is the only clearance, so it takes `max(DS.s4, safeAreaInsets.bottom)` —
  22pt on an iPhone 17, 0 on a phone with a home button. A flat 28pt stacked on
  top of the indicator instead and left ~50pt of empty sheet under the last
  button while the rest of the stack ran on a 16pt rhythm.

### SwiftUI gotcha already hit once

A `Button` with `.buttonStyle(.plain)` wrapping a `LabeledContent` only hit-tests
where text is drawn — the gap between label and value is dead space. Add
`.contentShape(Rectangle())` to the label. The dashboard meal rows do this.

## Design source of truth

UI follows `design_handoff_healthclean/README.md` — the full spec: screens,
colours, type, spacing, Vietnamese copy. Interactive prototype:
`design_handoff_healthclean/design/HealthClean Screens.dc.html` in a browser.
The `.dc.html` files are **design references, not code to port** — recreate them
in SwiftUI.

(The handoff's own `CLAUDE.md` writes these paths as `DesignHandoff/…`; the
folder is actually named `design_handoff_healthclean/`.)

**The History tab follows `design_handoff_healthclean/HISTORY_SPEC.md`, which
overrides the README's §6.11 for that screen** — the option chosen there ("1b",
logged-day cards with search and filters) is the one to build; the same page's
1a and 1c are alternatives that were rejected. Its own reference page is
`design/HealthClean History.dc.html`.

**The Profile tab follows `design_handoff_healthclean/PROFILE_SPEC.md`, which
overrides the README's §6.13** and adds a screen the README does not have, "Sửa
hồ sơ". Reference page: `design/HealthClean Profile.dc.html`. See the Profile
section for the five places the build departs from it and why.

### Rules

- Use `DesignTokens.swift` (`DS.*`) for every colour / radius / spacing /
  motion. Never hardcode a hex in a View.
- Do not change the Domain layer to fit the UI. The UI reads
  `CalculateCalorieGoalUseCase` and `EvaluateCalorieBudgetUseCase`.
- Blue `#0062B0` leads. Orange `#F37021` is reserved for the scan action alone.
  Green `#12B24C` is growth/success only.
- Over-budget state is **neutral grey, never red, never a command.** This is a
  health app for casual users, not a scold.
- **One language on screen, chosen on Profile.** §4 draws every label bilingual —
  Vietnamese primary with English beneath — and that is no longer what the app
  does; see the Language section for why the switch replaced it. Use `HFLabel`,
  whose second line is now for a genuine second *fact*, never a translation.
- AI results always show confidence and are always correctable. Nothing is saved
  before the user confirms.
- Hit targets ≥ 44pt. Font: Be Vietnam Pro (or the official FPT face) — never
  fall back to SF for headlines, the tracking assumes the geometric face.
- Numbers via a `vi_VN` `NumberFormatter` ("1.886"). Never concatenate strings.

Order of work is §13 of the handoff README: tokens + six shared views →
Dashboard → Onboarding → Manual/Detail/History → HealthKit → Scan/Review →
Insights/Profile → localization. Items 1–5 are done, plus Welcome (§6.1),
Profile (§6.13), Insights (§6.12) and the tab bar. What remains is real camera
capture and a real recognition provider (§6.6–6.9), and translating the catalog.

**Profile now follows `DesignHandoff/PROFILE_SPEC.md`, which overrides §6.13 for
that screen and adds "Sửa hồ sơ".** See the Profile section.

### Profile and Sửa hồ sơ — `PROFILE_SPEC.md`

`App/Presentation/Profile/`: `ProfileComponents` (`SectionLabel`,
`SettingsCard`, `SettingsDivider`, `SettingsRow`, `ProfileType`) /
`ProfileHeaderCard` / `SegmentedTrack` / `DisplayBlocks` / `NotificationSection`
(with `PrivacyCard` and `ProfileFooter`) / `EditProfileView` /
`EditProfileFields` / `EditProfileModel`, over the existing `ProfileModel`.
Reference page: `design/HealthClean Profile.dc.html`.

Profile shows a generic avatar rather than initials, because nothing in the app
ever asks for a name.

**The primitives are Profile's, not the design system's**, and the difference
from `HFCard` is one line of the spec: `SettingsCard` has **no shadow**. On a
long settings screen, cards stacked a section apart read as a seam rather than
as lift. `SettingsDivider` is placed by the caller rather than drawn by each row
— a row does not know its index, and "no divider before the first" is then
simply what the code looks like.

Four things the screen does that the spec does not draw, each because the spec
assumes something this app does not have:

- **"Đơn vị đo" has no chevron.** There is no units screen and no units setting;
  the app is metric and kcal throughout. The row states a fact, and a chevron
  that opens nothing is the broken control this codebase keeps refusing to ship.
- **The footer has no "Chính sách riêng tư" link**, for the same reason: there
  is no policy page. The three commitments above it are the policy this build
  has.
- **The eyebrow is "TÔI", not "TÔI · PROFILE".** The other three roots draw one
  word and the catalog answers the English. The pair is §4's bilingual label,
  which `AppLanguage` replaced.
- **The language segmented control keeps three options.** §2 draws two; "Theo hệ
  thống" already exists, works, and has a UI test.

**The appearance default stays `.light`**, not §2's "Theo hệ thống = bật". The
control is the spec's in full — Toggle above a segmented that dims and still
shows what the system chose — but the dark palette in `DesignTokens.swift` is
derived in this repo, and following the system would hand it to anyone whose
phone is dark without their asking. `AppAppearance` has carried that reasoning
since before this screen. The "the dark palette is invented" note under the
control is shown **only while dark is actually in effect**: a standing
disclaimer under a light screen is noise.

`AppearanceControls` is split from `AppearanceBlock` so §2's three states can be
*rendered* rather than described — a preview cannot put `@AppStorage` into a
chosen state.

#### Sửa hồ sơ (§5)

Push, not a sheet, and it replaces the four onboarding steps Profile used to
reuse. Those are right for a first run and wrong for an edit, where the user came
to change one number and needs to see what it does to the target.

- **The save routes through `OnboardingModel`.** Weight history is written from
  exactly one place — `OnboardingModel.save()`, which records the weighing after
  the profile lands — so `EditProfileModel` owns the draft and the arithmetic and
  hands the draft to the one writer there has ever been. A second writer is how a
  weighing quietly stops being recorded on one of two paths.
- Three things §5 draws are **deliberately absent**, all of them Domain features
  rather than layout: the "TỐC ĐỘ" segmented control (`WeightGoal` carries one
  fixed offset per direction, so all three positions would produce the same
  target), "Đặt mục tiêu thủ công" (no such screen), and "Ngày sinh"
  (`UserProfile` stores an age; a birth date is a store migration). A "Hướng mục
  tiêu" row is added in their place, because without the pace control there would
  otherwise be no way to change direction from this screen at all.
- **The reference page's own arithmetic does not hold**, which is worth knowing
  before that Domain change is designed: it deducts 320 kcal for 0,5 kg a week,
  and by its own stated conversion (7.700 kcal ≈ 1 kg) that is 550. Its figures
  are illustrative.
- **The safety floor is the Domain's, and it is stricter than §5's.** §5 names
  1.200 kcal (nữ) / 1.500 (nam); `CalculateCalorieGoalUseCase` clamps to
  `max(BMR, 1200)`, which binds higher for almost everybody. "Cách tính" writes
  out *which* floor caught a target — read off the result rather than compared
  against the constant, which is `internal` to Domain, so this screen holds no
  second copy of a number that can drift. `CalorieGoalTests` pins the floor as a
  **property** over a sweep of profiles, not only at two points, because that is
  the claim the screen makes.
- State **B** (a target below the healthy band) is grey, 1.5pt, offers a weight
  inside the band, and does not block "Lưu" — the same rule as the over-budget
  state. State **D** says the new target applies **from today** and that logged
  days keep theirs, which is HISTORY_SPEC §8 restated where the user can read it.
- Numeric fields edit a **`String`**, not the `Double`. `TextField(value:format:)`
  parses against the format's locale while the keyboard comes from the *phone*, so
  a Vietnamese UI on an English phone offers "." to a parser that wants "," and
  the field snaps back on every edit. Both separators are accepted; grouping
  separators are deliberately *not* stripped, since in `vi_VN` that would read a
  typed "98.5" as 985, and every field here is bounded under a thousand.

#### Three traps this screen paid for

- **`.confirmationDialog` does not present from this screen.** §5 names it and it
  was tried on the button, on the stack and on the screen: in all three the state
  flipped and nothing appeared, while the same change to `.alert` worked first
  time. State C uses `HFDestructiveConfirm`, which is where this app already went
  for the reason its own header gives — and which is what §5's mock actually
  draws, a card from the bottom with "Bỏ thay đổi" quiet above "Tiếp tục sửa" in
  blue. That component gained an `Emphasis` for it; `.destructive` is unchanged.
- **`accessibilityIdentifier` on a container propagates down and overwrites its
  children's.** Labelling a whole segmented control took the segments' own
  identifiers with it and left a row of buttons no test could name; the same
  thing on the out-of-range note would have hidden the only action in it. Put
  identifiers on leaves. Ask for `profile.language.en`, never `profile.language`.
- **A row whose trailing side is a control must not merge its children.**
  `.accessibilityElement(children: .combine)` plus `.isStaticText` is right for a
  label and a value — it stops VoiceOver reading every row twice — and it
  swallows a text field whole, leaving the only way to edit the number
  unreachable. `SettingsRow(hasInteractiveTrailing:)` is that switch, and the
  field carries its own label instead. A UI test found it by failing to see
  `field.weight` at all.

A choice sheet's rows merge name and description into one element, so nothing
matches them on the title alone — the `LabeledContent` trap in another shape.
They carry `choice.<field>.<rawValue>`.

**`#Preview` literals land in the string catalog.** A literal written into a
`LocalizedStringKey` is extracted whether or not the app ever draws it, so
preview scaffolding both adds keys to translate and keeps dead ones alive — a
gallery drawing `SectionLabel("TÔI")` kept the old eyebrow's key from ever going
stale. `find-untranslated.py` now ignores everything from a file's first
`#Preview` down, which is narrower than the whole-file entries in its `EXEMPT`;
preview copy uses the `verbatim` initializers.

### Weight history and Insights (§6.12)

`UserProfile.weightKg` is the one value the calorie model reads; `WeightEntry` /
`WeightRepository` are the history behind it. They are separate on purpose — the
profile is current state, the log is a record.

- Entries are written from **one place only**: `OnboardingModel.save()`, which
  Profile's "Thông tin cơ thể & mục tiêu" also routes through. `RecordWeightUseCase`
  skips a weight that has not moved, because the profile is re-saved whenever
  *anything* on it is edited and recording unconditionally would stack duplicate
  points for weighings that never happened.
- A failed weight write does not fail the profile save, the way health reads do
  not fail the dashboard. The profile was saved; the chart is secondary.
- `GetWeightSeriesUseCase` reduces entries to one point per week, keeping the
  most recent weighing in each. Weeks are 7-day blocks counted back from today,
  **not** calendar weeks, so the last point is always the latest weighing rather
  than a partial week. A week with no weighing produces **no point** — hence
  `WeightPoint.weekIndex`, which is how the chart places what it has and leaves
  gaps as gaps rather than carrying a stale value forward.

One of §6.12's four stat cells is deliberately absent, and one is conditional:

- "% bữa ăn được ghi" has no denominator — the app never learns how many meals
  the user meant to eat, and any figure would be invented.
- "% AI cần sửa khẩu phần" **is built**, over §22's record — see the AI
  correction record section — but is drawn only when something has been scanned
  in the window. A "0%" with nothing scanned reads as "the model got everything
  right" rather than as "it was never asked", which is the same mistake as a
  switch that schedules nothing.

The closing gray note of §6.12 is also absent; it needs an analysis of
afternoon protein that nothing specifies.

Hiding the navigation bar also hides the system back button, so any screen that
draws its own header must supply `HFBackChip` — edge-swipe is not a visible
affordance. This applies to pushed and sheet-presented screens; tab roots do not
need one. Apple Health still uses it.

### A tab root's eyebrow is structural, not decoration

Every root opens with an 11pt tracked eyebrow above its title — "HÔM NAY ·
TODAY", "THỐNG KÊ · INSIGHTS", "TÔI · PROFILE", all `HFType.eyebrow` on
`DS.textSubtle`, exactly as the reference page draws them. History is the
exception and is right to be: HISTORY_SPEC gives it a title plus an English
subtitle instead.

They were all missing, and that is what made the screens look wrong. Two
separate consequences, both worth knowing:

- **A 29pt title four points under the clock has nothing between it and the
  status bar.** The eyebrow is the element that was meant to sit there; without
  it the title is what butts against the time. The strips now take `DS.s2` above
  the safe area, matching HISTORY_SPEC's "top an toàn + 8" so all four roots
  agree.
- **History's is 16, not the 8 its own spec names.** HISTORY_SPEC's table says
  "top an toàn + 8" and that is what the other three take — but they open with an
  11pt eyebrow and History opens with a 26pt title, so the same number puts a much
  heavier line the same distance under the clock. The four roots are meant to look
  alike, not measure alike.
- **`.background { … }` stops at the safe area; `.background(aColour)` does not.**
  Three roots pass a `ShapeStyle` and bleed into the top inset for free. History
  draws a hairline under its header, so it needs the *ViewBuilder* overload — and
  that one respects the safe area, so its strip ended at the inset edge and day
  cards scrolled up through the status bar and the island. It takes
  `.ignoresSafeArea(edges: .top)` on the background's own stack. `HFTabBar`
  records this exact trap at the *bottom* of the screen; the same overload, the
  same fix, and it simply had not been applied at the top.
- **`ProfileView.header` was an empty `VStack`, which silently broke the mask.**
  The `safeAreaInset(edge: .top)` on these screens exists to give an opaque strip
  the job the hidden navigation bar used to do. An empty header has no height, so
  the strip was its 16pt of padding and nothing else — and Profile's switches
  scrolled up underneath the clock. The comment saying "same fix as the
  dashboard" was sitting directly above it the whole time. **If a root's header
  renders nothing, its content will scroll into the status bar.**

The §5 tab bar is complete: all four roots — Hôm nay, Lịch sử, Thống kê, Tôi —
plus the raised orange scan action between History and Insights. One thing §5
specifies is still absent: Welcome's "Tôi đã có tài khoản" link, because there is
no account system to sign into and a link that cannot do what it says is worse
than none. A tab that opens nothing is worse than an absent one.

### The history week strip — deleted, and what it left behind

There used to be a second History screen: `HistoryWeekStrip` /
`MealHistoryModel` / `MealHistoryView`, seven day columns with a dot under the
days that had meals, showing **one day at a time**. It was §6.11 plus a
navigation device the handoff does not draw, and for one release it was what
Release opened on while HISTORY_SPEC's list sat behind
`HistoryFeatureFlags.timeline` — §32.7's "bật flag cho nội bộ trước".

**All three files, the flag and its `-historyTimeline` launch argument are gone.**
§32.2's rule is that two ways to navigate one screen is not a shipping state, and
the spec was chốt, so the flag could only ever resolve one way. Three of its rules
outlived it and are documented where they now live:

- **Monday-first, shared, in `HistoryCalendar`.** `Calendar.current` starts the
  week on Sunday under a US locale. History's day boundaries have to be the
  dashboard's or a 23:30 meal lands on different days in different places, which
  is why the calendar is built once outside the view models and
  `DependencyContainer` hands it to `GetMealHistoryMonthsUseCase`.
- **A load pins the window it asked for and drops a result that arrives after the
  window moved.** Nothing orders two `@ModelActor` calls, so the slower of two
  in-flight reads landing last would leave the screen describing something it is
  not showing. `HistoryMonthsModel.loadGeneration` is the same guard, and it is
  now load-bearing for paging rather than for ‹ ›.
- **`yyyy-MM-dd` identifiers are built from date components, not a
  `DateFormatter`** (`HistoryCalendar.identifier(for:)`): it runs once per card per
  render and the formatter cannot be cached in a `static let`, not being
  `Sendable`, so it would be constructed every pass.

`AppDate.weekdayShort` and `dayText` went with the strip — nothing else
called them. `InsightsView` still carries its own three-line weekday helper, which
returns "Nay" for today; that is the copy the bar chart wants.

Two UI tests went too (`…SelectsADayAndPagesWeeks`, `…FindsAMealLoggedLastWeek`):
paging weeks and selecting a column are not behaviour any more.
`testHistoryListsTheDayAMealWasLoggedOn` keeps the part that still is — a meal
logged on the dashboard shows up as a card in History on the same launch, with no
fixture — and `testHistoryRefreshesAfterRemovingOneFood` now walks the day panel.

### The History screen — `HISTORY_SPEC.md`

The spec's "logged-day cards" (its option 1b) is built, in
`App/Presentation/MealHistory/`: `HistoryMonthsModel` / `HistoryMonthsView` /
`HistoryMonthSection` / `HistoryDayCard` / `HistoryDeviationBar` / `MealChip` /
`MealThumbnail` / `HistorySearch` / `HistoryStateViews` /
`HistoryDayPanelSheet`, over `HistoryMonth` / `HistoryDay` / `MealPhoto` and
`GetMealHistoryMonthsUseCase` in Domain and `MealPhotoEntity` + `MealPhotoStore`
in Data. `HistoryPreviewData` is `#if DEBUG` fixtures for the previews the spec's
§9 asks each piece for — the only previews in the codebase.

**The spec ratified a decision the code had already made.** `plan.md` §32 asks for
a Locket-style calendar; it was built, tried on device with a sparsely filled
store — three logged days among ninety cells, whole months of grey dots — and
replaced by a list, because MVP cannot back-date, so nine tenths of the grid
opened a sheet that could only say "nothing here". HISTORY_SPEC §0.1 now states
that as a rule ("ngày trống không tồn tại trong UI"), and `plan.md` is still not
edited to match: it is the spec, not a log.

What the spec added on top of the list: a deviation bar per day, a row of meal
chips, a pinned search field with filter chips, month headers with an average, a
one-line divider for an empty month, and a day panel with macros.

- **This is the History tab outright** — `MainTabView` builds `HistoryMonthsView`
  directly. It spent one release behind `HistoryFeatureFlags.timeline`; see the
  section above for what the flag was for and what its deletion took with it.
  Days are labelled `history.day.<yyyy-MM-dd>` by `HistoryCalendar`, which also
  owns the Monday-first calendar the screen and the use case share.
- **§8's per-day target is met, and it cost a stored field.** The bar compares a
  day against `Meal.calorieGoalWhenLogged`, stamped at save time by
  `SaveMealUseCase` — the one writer, so a flow added later cannot forget — and
  read back through `HistoryDay.goalCalories`, which takes the **last meal that
  carries one** (the target in force when the day ended, and the figure the
  dashboard showed that day). Before this, every past day's bar moved whenever the
  goal changed, because `UserProfile` holds one current goal that an edit
  overwrites.
  - The stamp is `Double?` on both `Meal` and `MealEntity`, which is what keeps
    the migration lightweight: existing rows get `nil` and need no conversion. A
    non-optional would need a default, and a default here **invents a target** for
    days the app never knew one for.
  - `nil` is not 0. A day whose meals all predate the field, or that was saved
    while the profile could not be read, has no target of its own, and every
    reader resolves that through one helper —
    `HistoryDay.goalCalories(fallingBackTo:)` — so the card, the day panel and the
    "vượt mục tiêu" filter cannot disagree. The fallback is the old behaviour, for
    old data only.
  - `SwiftDataMealRepository.update` deliberately does **not** write it: what a day
    was aiming for is not something editing a portion revises, and an `update` that
    wrote it would let a caller holding a hand-built `Meal` erase the only copy.
  - **Still today's figures: the day panel's three macro bars.** §6 asks for them
    and nothing records protein/carbohydrate/fat per day; stamping four numbers on
    every meal is a bigger change than §8 asked for. So one sheet mixes the day's
    calorie target with the current macro targets, which is worth knowing before
    reading a macro bar on a day from before a goal change.
  - The UI-test fixture stamps its −7d lunch with **1.900** while onboarding
    derives 2.378, and `testHistoryTimelineOpensADay` asserts the card names 1.900
    and not 2.378. That is the only place the field makes the round trip through
    SwiftData, so the day has to be able to disagree with today for a test to tell
    them apart.
- The bar's scale is `max(kcal, goal) × 1.12`, so a day exactly on target still
  has room to its right and the 1.5pt target mark never merges with the end cap.
  Over target is `DS.overBudget` grey, never red (§0.3).
- **A chip with a photo and a chip without are the same size** (§0.2). Most meals
  are typed in, so a layout that grew a photo cell would leave the ordinary day
  looking half-empty; the 26pt square is either the thumbnail or the dish's first
  letter on `DS.chipOnBg`. Chips are **not** buttons — one tap target per card, so
  a 38pt chip can never steal a tap meant for the day.
- The chip row is a `WrapLayout` (a small `Layout`), not `ViewThatFits` between an
  `HStack` and a `VStack`. It is how the design draws it (`flex-wrap`), and §4's
  "HStack → VStack from `.accessibility1`" then falls out by measurement: a chip
  wider than the card takes a line to itself. `ViewThatFits` *is* used for the
  card's date column, which cannot be measured away.
- **Search is scoped to the months already paged in, and says so.** Filtering runs
  over `months` in memory rather than querying the store, because "what the screen
  has" is exactly the scope §5 defines — a store query would silently widen it.
  Matching folds diacritics and case with a `vi_VN` locale, so "pho" finds "phở".
  250 ms debounce, nothing below two characters, and no spinner: the old list
  stays at opacity 0.5.
- A keyword or a chip **changes the unit of the list** from days to meals, because
  "which day was that" and "when did I eat phở" are different questions. A hit
  opens the *day panel*, not the meal detail — §4 keeps one way into a meal, and a
  second route would need its own copy of the delete and refresh plumbing.
- §5 says the keyword and the chips are not kept between two visits to the tab.
  That is not code: `MainTabView` switches on its selection, so leaving History
  destroys the view and the model with it. Moving the model up to the tab shell
  would quietly break it.
- **`HistoryMonth.days` holds only days with meals, newest first.** It used to hold
  every day of the month because a grid needs a cell for each; a struct field no
  view reads is the "broken control" mistake in data form. A month with nothing
  logged is still *returned* — paging counts months — and `HistoryMonthsModel.feed`
  turns it into `EmptyMonthDivider` **only when it falls inside the period the
  user has been logging in**. Empty months older than the first meal are dropped:
  they are not gaps in the record, they are time before there was one.
- One repository query per page, never one per day, and paging stops because
  `MealRepository.earliestMealDate()` says where the data ends. Without that floor
  "load more" pages into empty months for ever, since the store can always answer
  for one more month.
- **`loadMore()` keeps reading until something appears.** One page of three can add
  nothing visible, and a "load more" that visibly does nothing reads as broken. It
  chases up to six pages, then lets the user ask again. Paging is tracked by
  `loadedMonthCount`, not `months.count`.
- `HistoryDayPanelSheet` hosts its own `NavigationStack` so `MealDetailView` can be
  pushed inside the sheet, and the parent owns the delete toast — a toast cannot be
  shown from behind a sheet, so `onDeleted` closes the sheet first.
- **The day panel has no photo grid**, unlike the sheet it replaced. §6 enumerates
  what the panel holds — the total, the bar, the delta, three macros, the meals by
  time — and a picture at size is not in it. Its meal rows carry a 34pt thumbnail
  and `MealDetailView` one step deeper shows the photos full width. The version
  that opened with a 150pt photo pushed the calorie total below the detent on a
  small phone, and the numbers are what the sheet is *for*. `MealPhotoGrid` still
  owns the photos-at-size rules and is now used only by `MealDetailView`.
- A card grows downwards at accessibility text sizes and keeps everything, which is
  the other reason the list beat the grid: §32.6 had to drop the calorie figure
  from a 44pt cell to keep seven columns, and here nothing has to be dropped.
- The loading skeleton **pulses** (§6: 1.4 s, 0.45→0.95) and the pulse is gated on
  Reduce Motion, as is the fade when a thumbnail arrives. It was deliberately still
  before the spec asked for the pulse; a user who asked for less motion still gets
  the still one.
- §7 forbids a small grey on `pageBg` that cannot carry its contrast, and §2 draws
  the empty-month divider and the search footnote in #94A3B2 (~3.2:1). **§7 wins**:
  both take `DS.textMuted` (5.6:1). Between two hairlines the divider still reads
  as the quietest thing on the screen.
- Scroll position across a refresh and a trip into a day is not something the code
  does — it is something it avoids breaking: a refresh keeps `months` (same ids, so
  `ForEach` keeps its rows) and never blanks the screen. Because that is a claim
  which stops being true silently,
  `testHistoryTimelineKeepsItsScrollPositionAcrossADay` pins the card's `midY`.
  **That test needs the fixture's fortnight of days**: only logged days are cards,
  so without them the list is shorter than the screen and a scroll test that never
  scrolls passes without testing anything.
- **A pinned layout has to be able to give up and scroll.** `WelcomeView` was a
  fixed `VStack` with `Spacer`s, and `Font.custom(_:size:)` scales with Dynamic
  Type — so at an accessibility text size the copy grew until "Bắt đầu" sat below
  the screen with no way to reach it, locking a large-text user out of the app at
  its first screen. It is now a `ScrollView` whose content takes
  `minHeight: proxy.size.height`, so the `Spacer`s still work when it fits, with
  `.scrollBounceBehavior(.basedOnSize)` so there is no bounce then either. The
  onboarding steps and the Apple Health screen already scrolled; only Welcome did
  not. **A history UI test found this**, by failing to tap a button two screens
  earlier — an accessibility-size test exercises every screen it walks through, not
  only the one it is about.
- **A lazy stack keeps off-screen rows in the accessibility tree, but only for a
  little way past the viewport.** Two separate traps, both paid for: `tap()` on a
  materialised-but-off-screen row taps a coordinate outside the scroll view and
  hits nothing; and a row *further* down does not exist at all, where `frame`
  throws rather than returning zero. `scrollUntilHittable` handles both — it treats
  "absent" as "further down", the only direction it can be, and corrects for
  overshoot. Taller cards are what turned the second trap up: the same test passed
  on 78pt rows and failed on 125pt cards.
- §32.7 stage 3 also asks for minimal analytics. There is **none**, on purpose: the
  app has no analytics system at all. Events that go nowhere are the "switch that
  schedules nothing" mistake with less to show for it — and the notification
  switches, which used to be this rule's other example, were only added once
  something was behind them.
- Every new string goes through `Text` or `L(…)` and is synced into
  `Localizable.xcstrings` (165 → 208 keys: +47 for HISTORY_SPEC, −10 with the week
  strip, +6 that had been missing all along — see `GrayNote` in the Localization
  section; then 225 with §19's notifications and the tab-root eyebrows, and 348
  once the bilingual labels collapsed and every key gained an `en`). A separator or
  other non-copy literal uses `Text(verbatim:)`, or it lands in the catalog as a key
  to translate.

#### Meal photos (stage 2)

`MealPhoto` is **metadata only** — id, `capturedAt`, pixel size. No path, no URL,
no image: Domain cannot hold a `UIImage`, and a file path is a fact about one
installation rather than about the meal. `MealPhotoStore` (an actor, App-only)
maps the id to bytes under `Application Support/MealPhotos/{full,thumb}/<id>.jpg`.

- **Bytes first, row second, because nothing makes the two atomic.** A row
  pointing at a missing file would draw a broken day; a file no row points at is
  invisible and collectable. `Data.write(options: .atomic)` *is* the temp-then-
  rename §32.4 asks for — Foundation writes a sibling and renames it.
- The three cleanup paths, and all three are needed: `ScanModel.confirm` deletes
  the photo if the meal save throws; `delete(mealID:)` **returns the photo ids it
  removed** (as does `RemoveFoodItemUseCase.Outcome.mealDeleted(photoIDs:)`) so
  the App layer can delete files the cascade cannot reach; and
  `sweepOrphanPhotosIfNeeded()` collects the rest at launch. The sweep only runs
  when `photoIDs()` **succeeded** — reading a failed query as "no meal has
  photos" would delete the user's whole photo directory.
- The sweep runs *before* the UI-test fixture in `RootView`, not after: under
  `-uiTesting` the store is in memory, so every file from an earlier run is a
  genuine orphan, and the fixture then writes its own.
- **A cancelled scan cannot leave a temp file, because it never writes one.** The
  analysed bytes live in `ScanModel.analyzedImage` and reach the disk only inside
  `confirm()`. That is §32.4's "ảnh camera tạm phải bị xóa" satisfied by
  construction rather than by a cleanup path that can be missed.
- A photo that cannot be written **does not fail the meal** — same rule as a
  failed weight write not failing a profile save.
- `MealPhotoStore` returns thumbnail **`Data`**, not a `UIImage`: `Data` is
  `Sendable`, so the 1,600px original is downsampled inside the actor (240px,
  persisted, `NSCache` of 240 entries) and only that tiny image is decoded on the
  main actor, which is what §32.6 actually requires. A missing thumbnail with a
  surviving original is rebuilt rather than treated as a lost photo.
- **A SwiftData relationship array has no order**, so `MealEntity.meal` sorts
  photos by `(capturedAt, id)`. §32.3 forbids a picture that moves between renders,
  and the chip a meal draws is `photos.first` — from a set, that is whichever one
  the store felt like returning.
- **`HistoryDay.representativePhotoID` is deleted, and there is deliberately
  nothing in its place.** It was the newest meal that had a photo, and that meal's
  first photo — the rule a single day *cell* needed. HISTORY_SPEC's card draws a
  chip per meal, each with its own thumbnail, so a day no longer has one
  representative picture, and nothing outside its own test had read it for a while.
  Do not reintroduce a second rule for "the day's photo" beside `HistoryDay.photos`:
  two rules for which picture stands for a day is how they start disagreeing.
- §32.6's `history.day.photo.<date>` identifier is **deliberately absent**: a day
  merges into one accessibility element, which is what VoiceOver needs, so an
  identifier inside it could never be queried. The card's label carries "Có N ảnh"
  instead, which a test and a screen reader both reach.
- Photos are **not** excluded from device backup. §32.3 rules out iCloud, and the
  app has no CloudKit; excluding them would mean a restored phone showing rows
  whose pictures are gone, to satisfy a line that is about sync.
- **`MealDetailView` is where a photo is seen at size, and now the only place** —
  the day panel dropped its grid, see the History section. A tile keeps its own
  aspect ratio, taken from `MealPhoto`'s pixel dimensions, so it is the right shape
  *before* the bytes arrive and the layout does not jump when they do. That is what
  those two fields are for.
- `previewData(for:)` is a third size beside the 240px thumbnail and the 1,600px
  original: ~900px, downsampled on demand inside the actor and cached in memory
  for 8 entries rather than written to disk, because the original it comes from
  is already there and only one meal is ever open.

**The migration was verified against a store the previous build wrote**, not
assumed: a meal was logged into the on-disk store before `MealPhotoEntity`
existed, then read back after — dashboard total, meal detail and the history row
all intact. It is a lightweight migration (a new model plus a
to-many relationship that starts empty), so there is no `SchemaMigrationPlan`,
and if one ever becomes necessary the container's `fatalError` is how it will
announce itself. To redo that check: log a meal with no `-uiTesting`, change the
schema, relaunch. `xcodebuild test` uninstalls the app at the end of a run, so
seed and verify have to be in the **same** invocation (name the tests so
alphabetical order puts the seed first).

**`MealEntity.calorieGoalWhenLogged` and `FoodItemEntity.aiEstimatedName` have now
had that check run against them too**, together — both were added after `83cc285^`,
so one store written by a build at that commit is missing both and a single round
trip closes the pair. 14 meals and 15 food items were seeded there, then the
current build was installed **over** it without an uninstall: the container opened,
`ZCALORIEGOALWHENLOGGED` and `ZAIESTIMATEDNAME` were added with `NULL` in every
pre-existing row, and the days rendered with their calories and meal names intact.

The day cards read "trên mục tiêu 2.378" — no recorded target, resolved through
`HistoryDay.goalCalories(fallingBackTo:)` to today's. That is the interesting half
of the result: a wrong migration's likelier symptom here is a **0** target on every
old day, which draws a full over-budget bar rather than crashing.

Seeding needs a launch argument the app does not have. `seedUITestHistoryFixtureIfNeeded`
is gated on `-uiTesting`, which forces the *in-memory* store — precisely the store
that cannot be migrated — so the check relaxes that guard in a throwaway worktree
and launches with an on-disk store instead. Do not commit that relaxation; the
double guard is what keeps the fixture unreachable in a real build.

The verifying test cannot live in the suite either, and was deleted rather than
kept: it only passes against a store some earlier build seeded, so in CI it would
fail for a reason having nothing to do with the code. A 30th UI test that needs
manual setup to go green is worse than a documented procedure.

### Notifications (§19, PROFILE_SPEC §3)

PROFILE_SPEC §3 splits the five into two cards by **when they fire** — four in
"Trong ngày", one in "Cuối ngày" — rather than the flat list §6.13 draws. The
split is not cosmetic: the four are consequences of something the user just did,
and the fifth arrives whether or not they opened the app and is the one that
excludes the reminder beside it. `NotificationPreference.allCases` is still the
source of the set; the two arrays in `NotificationSection` only say which card a
switch is drawn in, so a preference added to Domain cannot silently vanish from
the screen.

The rows carry no times. §3 prints "· 12:00" and "· 21:00" in the English
sub-line that went away with §4's bilingual labels, and
`PlanNotificationsUseCase`'s hours are `private` — a literal here would be a
second copy of 20:00 that can drift, and the spec's 12:00 is not this app's
reminder hour anyway.


`PlanNotificationsUseCase` (Domain) decides *what* and *when*;
`NotificationCoordinator` (`App/Notifications/`) does the
`UNUserNotificationCenter` work; `NotificationCopy` writes the Vietnamese.
`NotificationSettings` holds the five switches in `UserDefaults`, for the
reason `AppAppearance` does — except it cannot be an `@AppStorage`, because the
coordinator is not a view.

The split is the same one `DisplayCopy.swift` records: `PlannedNotification`
carries a `Kind`, never a sentence, so the copy stays in the App layer and Domain
is not changed to fit the UI. **Changing the language re-plans**, because a
notification's words are chosen when it is scheduled — the picker on Profile calls
`refresh()` for the same reason the switches beside it do.

- **§19 has four budget triggers and §6.13 draws three switches.** `reached` and
  `exceeded` share one: passing the target and hitting it are one event to the
  user, and a separate switch could only ever fire after the other already had.
  `CalorieBudgetStatus.notificationPreference` is that mapping.
- `CalorieBudgetStatus` is `Comparable` now, and that is what the whole rule set
  rests on: an alert fires only when the day climbs *above* the highest rung
  already announced today. The mark is stored beside the `yyyy-MM-dd` it belongs
  to, so it expires at midnight, and it is written whether or not anything was
  delivered — otherwise turning a switch on at 11pm would fire the morning's
  threshold retroactively.
- **A budget alert fires 20 seconds after the meal that caused it**, and there is
  deliberately no `UNUserNotificationCenterDelegate`. Without a delegate iOS shows
  no banner while the app is in the foreground, which is right — the dashboard is
  already drawing the same figure in a ring. The delay is what gives a user who
  logged and put the phone down a chance to see it on the lock screen. If the day
  falls back below the mark inside those 20 seconds (a food was removed) the
  pending request is taken back.
- **The reminder and the summary are mutually exclusive**, decided by whether
  anything has been logged: an empty day has nothing to summarise, a logged day
  needs no reminding, and a user with both switches on gets exactly one evening
  notification. Profile says so in a `GrayNote`, because two switches that quietly
  exclude each other read as a bug.
- **Only today is ever scheduled.** The summary carries the day's real figures,
  which are not knowable in advance, and a reminder for tomorrow would fire on a
  day the app never saw. So both are re-planned every time the app learns
  something, and a day the app is never opened on produces nothing. A notification
  that had to invent its own contents is the "switch that schedules nothing"
  mistake with a payload.
- **20:00 and 21:00 are this repo's choice, not the spec's** — §19 names no time.
  An hour apart so the two can never collide.
- The re-plan hooks are `DashboardModel.load()` (which every manual entry, every
  deletion and every profile edit already ends in), plus `MainTabView` on launch,
  on `scenePhase == .active`, and after a scan saves — the scan can be started
  from any tab, so the dashboard's hook is not guaranteed to run.
- **The switches are inert until iOS has granted permission, and say so.** Nothing
  is requested at launch: Profile draws a banner and a button, and after a denial
  a link to Settings, because a live-looking switch over a denied permission is a
  broken control that also lies about it. Only `.alert` and `.sound` are asked
  for; nothing sets a badge.
- Under `-uiTesting` the coordinator never touches the system — the suite cannot
  answer a permission dialog, the same rule that keeps it out of the HealthKit and
  Photos sheets. `-notificationsGranted` then stands in for a granted permission
  so the switches can be walked; the scheduling stays inert either way.
- **Both halves were verified for real on a simulator**, with a throwaway test that
  granted the permission through SpringBoard: logging 1.700 kcal against a 2.378
  target backgrounded the app and produced a "Đã dùng 70% ngân sách calo" banner,
  and an empty day produced "Chưa có bữa nào hôm nay". To redo it, force
  `NotificationCoordinator`'s `isEnabled` to `true` and, for the scheduled half,
  make `dailySchedule` fire a minute out instead of at 20:00.
- The evening notifications use a `UNCalendarNotificationTrigger`, not the
  equivalent interval: 20:00 has to stay 20:00 if the user changes time zone.

### Camera / AI (§6.6–6.9)

The gateway lives in its own repo at `~/Projects/healthclean-gateway`
(FastAPI). The iOS side talks to it through `FoodRecognitionRepository`.

**Which repository runs is chosen by environment**, not code:
`GATEWAY_URL` points at a running gateway, `MODEL_PROVIDER` overrides which
model it uses. With neither set the app uses `MockFoodRecognitionRepository`,
which is the honest default — a scan that always failed would teach nothing.

Gemini is the verified hosted POC provider. Qwen has an OpenAI-compatible
adapter but remains unverified until an endpoint is selected. Switching stays
configuration-only through `MODEL_PROVIDER` / `X-Model-Provider`.

`GATEWAY_API_KEY` is read the same way and sent as `X-API-Key`. A gateway on
localhost needs none; a deployed one rejects every `/v1` call without it,
because an analysis spends a call on the operator's model quota. Both values go
through one `setting(_:)` helper in `DependencyContainer`, which exists because
an unset build setting still leaves the **key present** in `Info.plist` — only
the value tells you it was never configured, so `nil` is never what you get.
Measured on a Debug simulator build with neither defined, `$(GATEWAY_URL)`
expands to `""`; the helper's empty check is therefore the branch that actually
fires. It also rejects a literal `"$(NAME)"`, the other documented outcome when
expansion does not run, which has not been re-measured on a device build.

**The gateway is HTTPS on `heathclean-gateway.chillcat.dev`, and
`NSExceptionDomains` is gone.** It used to name the deployed gateway's bare IP so
that plaintext HTTP to that one host was permitted — a bare IP cannot hold a
certificate — and the stated condition for deleting it was "give the gateway a
domain and a certificate, then delete the whole dict". That condition was met, so
it went, and with it the API key and every meal photo crossing the wire in clear
text.

Two things this simplifies, and one trap it removes:

- **`GATEWAY_URL` and the plist no longer have to be kept in step.** Pointing the
  script at any other `https://` host now needs no plist edit. That coupling was
  the sharp edge: an exception is matched on an exact literal, nothing derived it
  from `GATEWAY_URL`, and the two could disagree silently with a network error as
  the only symptom.
- **`NSAllowsLocalNetworking` stays**, and is far narrower than what was removed:
  it relaxes ATS for the local network only — `192.168.x`, `.local`, link-local —
  and never for a public address. It is what makes
  `GATEWAY_URL=http://192.168.1.20:8000` work against a gateway on the Mac.
- `NSAllowsArbitraryLoads` was never the tool for any of this: it disables ATS for
  every host the app will ever contact, to fix one.

Do not add an exception back for a new deployment. The answer to a plaintext host
is a certificate; on the local network it is already covered.

**The HTTPS path has been run on a physical iPhone**, not only curled: a scan
reached the deployed gateway and came back naming the dish that was actually
photographed. That last clause is the whole of the check — `MockFoodRecognitionRepository`
returns the same four items (Cơm trắng, Sườn nướng, Chả giò, Món chưa rõ) for
every image, so a scan that "works" proves nothing on its own, and a result that
matches the photo is the only cheap evidence the request left the phone.

`CameraCaptureView` is §6.6 in full — `AVCaptureSession`, the preview layer, the
1:1 viewfinder. The capture → gateway → review → save path has been exercised on
a physical iPhone; the simulator still uses `PhotosPicker` because it has no
capture device. Two implementation details remain important:

- `MealImagePreprocessor` applies EXIF orientation, downsizes to 1,600 px and
  emits JPEG at 0.78 quality before upload. Camera and library images share this
  path, so HEIC bytes are never mislabeled as `image/jpeg`.
- `NSCameraUsageDescription` is in `Config/Info.plist`. Without it the app
  **crashes** the first time it touches the camera, on device, with no warning
  from the simulator.
- **The simulator lies about having a camera.**
  `UIImagePickerController.isSourceTypeAvailable(.camera)` returns `true` there,
  which sent the whole flow into the camera screen and broke the scan UI test.
  It is asking about the legacy UIKit picker, not about capture. The gate that
  is actually true is `CameraCaptureView.isAvailable`, which asks AVFoundation
  for the very device the session needs — and that is `nil` on a simulator.

The session is stopped on `.background` and restarted on `.active`: iOS stops it
when the app leaves the foreground and `.task` does not run again on return, so
without that the viewfinder comes back black after a call or a lock.

**The scan flow is the one place the app goes dark.** §6.6 (camera) and §6.7
(analysing) sit on `DS.scanSurface`; §6.8 (review) returns to the light surface,
which is what the handoff draws. **§6.7's dark failure screen is gone** — a
failure now lands on §6.8 with the photo and no items; see "A failed analysis is
not a dead end". `DS.scanSurface` and `DS.scanViewfinder` live beside the camera
code rather than in
`DesignTokens.swift` because nothing else uses them. The `.ds(.ghost)` button
style is drawn for a light surface, so the dark screens style their text actions
inline instead of reusing it.

§6.7's progress bar stops at 95% and waits. The real work is one network request
of unknown length, so filling the bar would be a claim the app cannot make —
what ends that screen is the response arriving. The three checklist rows are
still driven by the timer, not by real pipeline stages, because the gateway
reports one result rather than progress.

**A high confidence is not evidence the dish is right.** Three photos through
`gemini-3.1-flash-lite`: phở → Phở bò at 1.00, bánh mì → Bánh mì thịt at 0.95,
and **bún bò Huế → Phở bò at 0.98**. The miss is fair — both are beef noodle
soups — but `RecognizedFood.lowConfidenceThreshold` (0.75, §4) will never flag
it, so §6.8's "Nên kiểm tra" badge does not catch this class of error. What
protects the user is that the dish name is prominent and correctable, not the
number beside it. Do not add behaviour that treats a high confidence as a
guarantee.

### An unresolved food, and why renaming does not fix it

The gateway decides `isResolved`; the client never looks a name up. So
`ScanModel.rename` changes a string and nothing else — and because `canConfirm`
requires *every* food to be resolved, a dish outside the gateway's nutrition
table could not be saved at all. The first live scan hit this immediately. The
development table now has 88 rows, but an unresolved result remains a normal
branch rather than an exceptional one.

`RecognizedFood.resolved(calories:protein:carbohydrates:fat:)` is the way out,
reached from the portion editor. Only calories are required; the macros may be
left blank. `plan.md` §2 gives nutrition to the database but says nothing about a
dish the database does not know — this is that branch, and §4's "always
correctable" is why it belongs to the user rather than to a guess.

**Nutrition is entered for the portion on screen, not per 100 g**, and
`originalWeightGrams` is deliberately *not* reset to that weight. Resetting it
is the obvious implementation and it silently destroys `wasCorrected`, which is
what §22 measures a portion correction against. It turns out to be unnecessary:
`scaled(toWeightGrams:)` already derives its baseline from the current values,
so hand-entered figures rescale correctly on their own. Two tests pin both
halves of that.

The UI copy is load-bearing here and was wrong at first. It said "sửa tên hoặc
bỏ món này", inviting the one action that cannot work. Anything written next to
an unresolved item has to point at the nutrition entry or at removing the item.

### A failed analysis is not a dead end

`ScanModel.State` has **no `failed` case**, and that absence is the feature. §6.7's
dark error screen offered "Thử lại" (back to the camera) and "Nhập tay" (close the
scan and open `MealEntryView`), and **both threw the photo away** — so a plate the
gateway could not read could not be logged at all, even though the person holding
the phone knew exactly what was on it. One unreachable gateway broke the whole
flow.

A failure now lands on the **review screen** with `analysisFailure` set: the same
photo, an empty list, and a note where §6.8's blue explainer pill goes. The list is
filled by `RecognizedFood.typedByHand()`, which resolves through the same
`resolved(…)` a dish outside the nutrition table takes — so nutrition is typed in
one place rather than two, and the saved meal keeps the photo because it is the
ordinary `confirm()` that saves it.

- **`RecognizedFood.confidence` is `Double?` for this**, and the optionality is
  what keeps §22 honest. A hand-typed food has no prediction behind it, so
  `foodItem` writes `nil` to `aiConfidence` *and* to both `aiEstimated…` fields —
  otherwise `originalName`/`originalWeightGrams`, which are `let` and therefore
  always set, would file the user's own first guess as the model's prediction and
  every §29 accuracy figure would count rows the model never saw. `isFromModel`
  (`confidence != nil`) is the marker, mirroring `FoodItem.cameFromScan`, and
  `wasRenamed`/`wasPortionCorrected` both answer `false` without it — they have to
  agree with what `FoodItem` says after the save, which `AICorrectionTests` pins.
  Making it `Optional` rather than passing 0 also means no screen can draw a
  confidence badge for a figure nobody predicted: the compiler asks first.
- **"Thêm món bằng tay" is drawn on a successful review too.** A model that reads
  three dishes off a plate of four leaves the fourth exactly as unreachable, and
  §4's "always correctable" covers what was missed as well as what was wrong.
- **Retrying the analysis is offered only while the list is empty.** A retry
  replaces the whole result, so once anything has been typed there is work to
  lose, and this app asks before losing work. It re-sends the bytes already in
  hand rather than the user re-taking a photo that was fine — the quota cost is
  the same as any scan.
- **A failed *save* no longer replaces the screen either.** It used to set
  `.failed`, which discarded every correction the user had just made; it is now
  `saveError` drawn under the total, with the meal still there and a retry one
  tap away.
- The note is **orange, not `DS.danger`**: nothing has gone wrong with the user's
  day, one request did not come back. Same rule that keeps the over-budget state
  grey (§0.3).
- The identifier is on the note's **sentence**, not on the card around it. A
  container's `accessibilityIdentifier` propagates down and would have taken the
  retry button's with it — the trap PROFILE_SPEC's segmented control paid for.
- **`-scanFailureFixture` (with `-uiTesting`) is the seam**, the same double guard
  as the other fixtures: `FailingFoodRecognitionRepository` throws
  `.unreachable` for every image. The branch was unreachable otherwise — the mock
  always succeeds and a real gateway cannot be made to fail to order — and since
  the whole claim is that *the flow survives*, it had to be walkable or the claim
  would quietly stop being true.
  `testAFailedAnalysisKeepsThePhotoAndTakesTheMealByHand` walks it end to end:
  note, photo, add by hand, name, calories, save.
- What it deliberately does **not** do is fall back to `MealEntryView`. That
  screen cannot carry a photo — `MealEntryModel` has no photo store and building a
  second path that could is how two writers of the same thing start disagreeing.

Reaching §6.8 means driving the system Photos sheet, which the suite avoids for
the same reason it avoids the HealthKit sheet — so the path had no UI test at
all. **`-scanFixtureImage` is the seam**: under the same double launch-argument
guard as the history fixture, `ScanFlowView` generates a frame and hands it to
`acceptImage`, so only the picker is skipped and the preprocessor, the
recognition repository and the review screen are the real ones. The portion
editor and the nutrition entry are still hand-only.
`MockFoodRecognitionRepository` does return one unresolved food, so that half is
exercisable by hand on a simulator — and the portion editor's name field and its
nutrition box are now driven by a test as well, through
`-scanFailureFixture` (below), which is the one path that has to type a whole
food in from nothing.

Sending meal photos to a hosted service is what `plan.md` §20 and §21 already
describe — the image is analysed and deleted, never persisted server-side. The
privacy line on Profile is about *health* data staying on device, which remains
true either way.

What was measured on this machine, so it need not be rediscovered:

| | |
| --- | --- |
| Python | 3.9.6 (system). Fine for FastAPI; `mlx-vlm` may need 3.10+. |
| `uv` / `poetry` | absent; only `pip3` |
| `ollama`, `llama-server`, `lms` | none installed |
| Model API keys | none set (no `GEMINI_*`, `DASHSCOPE_*`, `HF_TOKEN`, …) |
| Hardware | M1 Pro, 32 GB — can run a quantised 3B–7B VLM if one is installed |
| Camera | **AVFoundation does not work in the simulator.** `PhotosPicker` does, so the picker path is testable and the capture path is not — §6.6 is written but can only be verified on a device. |

So with the machine as it stands, only a mock provider can be verified end to
end. The Qwen and Gemini paths can be written but not run. Plan the work that
way, or install a model first.

Local inference was ruled out, so the ollama/MLX comparison below is moot unless
that changes.

The contract to build against is §25 (`POST /v1/meals/analyze`) and the Domain
seam is `FoodRecognitionRepository` from `plan.md` §9 — which does not exist yet.

**The iOS half is not blocked.** With the seam plus a mock provider, the scan
state machine and the review/portion-editor screens (§6.6–6.9) can be built and
verified here without the gateway or a key. Only the real recognition path
waits.

### The AI correction record (§22, and what §29 can measure from it)

§22 wants the model's prediction stored beside what the user confirmed. Three of
§29's four measures now come out of the store for free; the fourth needed a
field.

| §29 measures | Where it comes from |
| --- | --- |
| Portion estimation error | `FoodItem.aiEstimatedWeightGrams` vs `weightGrams` |
| Nutrition resolution rate | `nutritionSource == "user_entered"` — the gateway could not resolve it and the user typed the figures |
| Food identification accuracy | `FoodItem.aiEstimatedName` vs `name` |
| User correction rate | `wasCorrected` = either of the two above |

**`RecognizedFood` and `FoodItem` answer these under the same names**, and for a
while they did not: `wasCorrected` meant the portion alone on the proposal and
either half on the saved item. Two closely related types disagreeing under one
name is how a rate quietly starts counting the wrong thing —
`AICorrectionTests` now pins that the proposal and the item it becomes give the
same three answers.

- **`RecognizedFood.originalName` and `originalWeightGrams` are both `let`, and
  that is the whole safety mechanism.** `rename` assigns `.name`; `scaled` and
  `resolved` both go through `var copy = self`. A `let` survives all three by
  construction rather than by anyone remembering — which matters, because
  resetting the original is the obvious-looking implementation and it silently
  destroys the measurement. Two tests in `AICorrectionTests` pin each path.
- **`aiEstimatedName` exists because a rename is the only trace a
  misidentification leaves.** `gemini-3.1-flash-lite` returned bún bò Huế as
  "Phở bò" at 0.98; `lowConfidenceThreshold` will never flag that, and before this
  field the user correcting the name overwrote the only copy of what the model
  said. Data not recorded at the moment of confirmation cannot be recovered later.
- Names are compared through `VietnameseTextComparison`, which trims and folds
  diacritics and case under `vi_VN` — so "Pho bo" typed over "Phở bò" is a
  *confirmation*, not a correction. Counting keyboard habits as
  misidentifications would inflate every accuracy figure. It is deliberately not
  `HistorySearchText`: same technique, different question, and that one lives in
  Presentation and does not trim.
- **`nil` is not "the model was right."** Rows written before the field read back
  `nil`, and `wasRenamed` reads that as "nothing to report". A `nil` treated as a
  match would quietly count every pre-existing meal as a success.
- **A food typed in on the review screen is not in any denominator**, the same as
  one typed into `MealEntryView`. It reaches the store with `aiConfidence` and
  both `aiEstimated…` fields `nil`, which is what `RecognizedFood.confidence`
  being `Optional` buys — see "A failed analysis is not a dead end".
- Rates are counted **per food, not per meal**: a plate read as three dishes with
  one wrong is one correction in three, and rolling it up to the meal would
  report a total failure.
- `FoodItemEntity.aiEstimatedName` is the third lightweight migration in this
  store, the same shape as `MealEntity.calorieGoalWhenLogged` — a new optional
  attribute — and the on-disk check **has** been run against both, in one pass,
  since a build from before either existed is missing both. See the meal-photos
  section. Old rows read back `NULL`, which `wasRenamed` already treats as
  "nothing to report" rather than as a match.
- The UI-test fixture scans two foods and corrects one, so Insights reads 50% —
  a figure distinguishable from both "nothing scanned" and "everything wrong".
  Their names, weights and calories are untouched, so no other fixture assertion
  moves.

**What is still missing is the dataset, not the instrumentation.** §29 asks for a
labelled set across eight categories — Vietnamese, Western, multi-dish plates,
soups, drinks, packaged food, unclear images, partial dishes — and the harness
that scores it belongs in the gateway repo. Nothing here can produce either.

### Localization

`App/Resources/Localizable.xcstrings` holds every user-facing string; the
project's development language is `vi`, so Vietnamese *is* the source language
and there is no separate base file.

`xcodebuild` extracts strings into `.stringsdata` but does not write back to the
catalog — only the Xcode IDE does. To refresh it from the command line:

```bash
find ~/Library/Developer/Xcode/DerivedData/HeathFirst-*/Build/Intermediates.noindex/HeathFirst.build \
  -name '*.stringsdata' > /tmp/sd.txt
/Applications/Xcode.app/Contents/Developer/usr/bin/xcstringstool sync \
  App/Resources/Localizable.xcstrings --stringsdata $(tr '\n' ' ' < /tmp/sd.txt)
```

Only `Text("…")` and other `LocalizedStringKey` positions are extracted
automatically. A string built as a plain `String` — an error message, a status
line — must be wrapped in **`L(…)`** or it silently stays out of the catalog.
`L` is this app's replacement for `String(localized:)`; see the Language section
for why, and note that extraction still works through it — the compiler follows
the `String.LocalizationValue` literal at the call site.

**A shared view whose text parameter is a `String` takes every literal written into
it out of the catalog, and nothing says so.** `GrayNote` was declared `let text:
String`, so six pieces of copy passed to it as literals — the Apple Health privacy
line, the scan explainer, two onboarding asides, two Insights empty states — were
never extracted. It went unnoticed because the catalog *did* have the History day
panel's empty-state sentence: the week-strip screen happened to pass the same words
through `String(localized:)`, and deleting that screen took the key away and left
the panel's own copy visibly unlocalizable. `GrayNote` now takes a
`LocalizedStringKey`, with `init(verbatim:)` for a message that was already
localized where it was built. **When a component takes text, take a
`LocalizedStringKey`** — and if it must also accept resolved strings, give that its
own initializer rather than one `String` doing both jobs.

`xcstringstool sync` decides what is stale from the `.stringsdata` you hand it, and
DerivedData keeps the `.stringsdata` of **deleted** source files. So a sync after
deleting a screen quietly reports nothing stale; remove the orphaned
`<DeletedFile>.stringsdata` (or clean-build) or the dead keys stay.

**The catalog is fully translated, `vi` source and `en`** — 343 keys before
PROFILE_SPEC, 414 after it (+79 for Profile and Sửa hồ sơ, −8 stale ones the old
Profile took with it), 426 with Phase 5's fibre and water, and **438** once a
failed analysis became a screen the user can finish (+13, −1 the deleted error
screen took with it). Every key carries an explicit `vi` value equal to
itself, which is what makes `vi.lproj` exist; `ResolvedLanguage.bundle` records
why that matters. It used to
carry no translations at all, deliberately, because §4 made the UI *bilingual* —
`LabelPair` drew Vietnamese and English at once, so an `en` locale would have
turned "Bước chân / Step count" into "Step count / Step count". That is no longer
the shape of the UI; see the Language section.

A key with no `en` value falls back to the key itself, which is Vietnamese — so a
missed translation shows up as one Vietnamese line in an English screen rather
than as an error. `Scripts/find-untranslated.py` is the check, and it looks for
three silent failures — see the Language section for what each one is and for the
one it cannot see.

### Language (Tiếng Việt / English)

`AppLanguage` (`App/Presentation/DesignSystem/AppLanguage.swift`) is the same
shape as `AppAppearance` — `@AppStorage`, three cases, read at the app root — and
resolves to a `ResolvedLanguage`, which is a separate type so `.system` can never
reach a `Locale(identifier:)` or an `.lproj` lookup and fail quietly.

**This replaced §4's bilingual labels rather than joining them.** The handoff
draws Vietnamese on the primary line with English beneath, which is right when
there is no way to choose; with a switch it shows the user a language they did not
ask for, and an `en` locale would have printed "Step count / Step count".
`LabelPair` is therefore `HFLabel` and draws one line. Its `caption` slot is *not*
the English coming back: it is for a genuine second fact — "Dùng cho công thức
Mifflin-St Jeor" under "Giới tính sinh học" — which lived in the `en:` parameter
only because that was the only parameter there was.

**There are two resolution paths and only one is automatic.**

- `Text("…")` inside a view follows `\.locale`, set once at the app root beside
  `preferredColorScheme` and for the same reason: it has to sit above every sheet.
- **`String(localized:)` does not.** It asks `Bundle.main.preferredLocalizations`
  — the *phone's* language, not the choice on Profile — so a model that builds its
  own copy would leave half a screen in the other language. Every string built
  outside a `View` goes through **`L(…)`**, which passes the resolved language's
  bundle and locale explicitly. Extraction still works: the compiler follows the
  `String.LocalizationValue` literal at the `L` call site, so `xcstringstool` sees
  it exactly as it saw `String(localized:)`.
- The app root also takes `.id(language.resolved)`. A string a model already built
  and stored resolved once, at load, and no environment change reaches it;
  rebuilding the tree re-runs every `.task`. Changing language is deliberate and
  rare, and losing the navigation stack is the right price for a screen that is
  wholly in one language.

**Numbers and dates follow the language**, which is why `VNNumber` is `AppNumber`
and `VietnameseDate` is `AppDate` — the old names became lies the moment either
could render "Thursday, 8/13". `AppDate` is mostly ICU: a localized *template*
("EEEE d M") lets each locale order and punctuate, so `vi_VN` answers "Thứ Năm,
13/8" and `en_US` "Thursday, 8/13" from one line. Four functions still branch,
each for its own reason, and the comments say which: ICU decides *format*, the
design decides *copy*, and where the handoff wrote the Vietnamese words itself
those words win ("Tháng 8, 2026", "Th 5").

**`weekdayNarrow` is the fourth, and it exists because two screens wrote the same
string meaning different things.** §6.12's bar chart labels a weekday "T2"; the
weight chart beside it labels a *week* "T2". One catalog key, `T%lld`, and
whichever English you give it is wrong on one of the two charts — "W2" under a
Monday, or "Mon" over week two. The weekday one therefore branches in `AppDate`
and never reaches the catalog, and the week one keeps the key.

That pair is also the one thing `find-untranslated.py` structurally cannot catch:
the calorie chart's axis was three raw literals, and the script saw text that
matched a key another screen had registered and said nothing. **A string
localized at one call site and raw at another is invisible to it.** Looking at
the screen in English is what found it, which is why that check is worth doing by
hand after a change of this size.

**Three things deliberately do not follow the language**, and all three look like
they should:

- `HistoryCalendar.mondayFirst()` sets `firstWeekday` outright and attaches no
  locale. It used to take Monday from `vi_VN`, which was the same answer by
  accident — `en_US` starts the week on Sunday, and these boundaries are shared
  with the dashboard through `GetMealHistoryMonthsUseCase`, so a display
  preference would have moved which week a 23:30 meal belongs to.
- `VietnameseTextComparison` (Domain) and `HistorySearchText` stay `vi_VN`. They
  fold diacritics for **dish names**, which are Vietnamese whatever the UI reads.
- System permission dialogs read `Config/Info.plist` and follow the *phone's*
  language — iOS picks before the app runs. Those three `…UsageDescription`
  strings are English and are not localized at all; putting them in an
  `InfoPlist.xcstrings` is separate work and still would not obey the switch.

`-uiTesting` pins the language to Vietnamese unless `-appLanguage en` says
otherwise, and `applyLaunchOverrideIfNeeded` writes that into `UserDefaults` so
`@AppStorage` and `AppLanguage.current` cannot disagree. Without the pin the whole
suite would fail on a simulator set to English, for a reason having nothing to do
with the code. Two tests cover the feature:
`testLaunchingInEnglishTranslatesBothTheCopyAndTheNumbers` (copy and figures
travel by different mechanisms and fail independently) and
`testSwitchingLanguageOnProfileChangesTheOtherTabs` (what `.id()` buys, and the
half that fails silently).

`Scripts/find-untranslated.py` is the standing check, and it looks for three
failures, all of which render as working software: a Vietnamese literal that never
became a key, a key with no `en`, and **any surviving `String(localized:)`**.
Deliberate Vietnamese is listed in the script's `EXEMPT` with its reason.

That third check is there because the conversion to `L()` was done with a search
for `String(localized: ` on one line, and **eight calls wrapped the argument onto
the next line and were missed** — including the rescan warning's first sentence and
the History search empty state, both visible copy. Nothing else finds them: they
resolve to a real catalog key, so the first two checks see nothing wrong, and the
only symptom is a sentence in the phone's language on a screen drawn in the other.
A code review found them; matching `localized:` alone is what keeps them found.

### Two token sets exist — know which you are in

`DesignTokens.swift` (`DS.*`) is the handoff's palette and the one new work must
use. `DSPalette`/`DSColor`/`DSType` came from an earlier sync of the claude.ai
Design project and carry **slightly different values** (`surfacePage` `#F8FAFC`
vs `#F4F7FA`, `textBody` `#1F2E3D` vs `#2B3947`, `danger` `#D5342B` vs
`#D64545`). Do not mix the two in one screen.

`DSColor` is also appearance-adaptive while `DS.*` is light-only, so a screen on
`DS.*` will not respond to dark mode.

Dashboard, onboarding, manual entry, meal detail and history are all on `DS.*`
now. What still uses the older set is `DisplayNames.swift` and the `DS*`
components under `DesignSystem/`.

**`DSButtonStyle` is the exception that matters**, and it is not decoration:
`.ds(.primary)` / `.ds(.ghost)` are on Welcome, Onboarding, Apple Health, the
scan failure screen, review and the portion editor, and they read `DSColor`,
which is appearance-adaptive. Every *light* value there matches `DS.*` exactly
(brand `#0062B0`, accent `#F37021`, card white), so in light mode the two
palettes agree — but in dark mode the buttons moved while the screens, being on
light-only `DS.*`, did not. Apple Health's "Để sau" drew `#86BEEA` on a white bar
at ~1.9:1.

`DS.*` now has a dark palette of its own, so the two sets move together. **Every
dark value in `DesignTokens.swift` was derived in this repo**, exactly as
`DSColor`'s was — the handoff and the FPT IS system behind it are light-only.
That file's header records how each group was derived; replace the lot if the
brand team publishes real values.

The one non-obvious rule in it: **the tint ramps swap role between appearances.**
`blue50`…`blue200`, `orange100`, `green100` are tint *backgrounds* in light, so
they become deep tints in dark; `blue700`, `orange700`, `green700` are *text on
those tints*, so they become light. Getting that backwards is the fastest way to
make a screen unreadable. `neutral900` also *lifts* rather than darkens, because
it is §6.14's toast fill and a #0F1B27 pill on a #0B1219 page is invisible. The
three brand colours stay absolute — an identity that changed with the appearance
would not be an identity.

`AppAppearance` (`@AppStorage`, chosen on Profile) owns the choice and is applied
as `preferredColorScheme` at the app root, which is why there is **deliberately
no `UIUserInterfaceStyle` key** in `Config/Info.plist` — it would override the
setting and make "Tối" do nothing silently. It is a display preference with no
bearing on any calculation, so it is not Domain state.

**The default is `.light`, on purpose**, so nobody gets an invented palette just
because their phone is dark. `.system` becomes the right default once the dark
values are real — **including over PROFILE_SPEC §2**, which draws "Theo hệ
thống" switched on by default. The control is built exactly as §2 specifies; only
its starting value differs, and the Profile section says so.

The language switch beside it works the same way and is documented in the
Language section. It is the same shape — `@AppStorage`, three cases, applied at
the app root — with one difference that matters: its default is `.system`, because
unlike the dark palette there is nothing invented about the English.

## Scope

`plan.md` is the product spec — 31 sections, 8 phases. It is the source of truth and
should not be edited as a side effect of implementation work.

**Phase 1** is complete: profile, BMI, calorie/macro targets, manual meal entry,
meal history, dashboard, warning engine, SwiftData.

**Phase 2** is partially done: HealthKit authorization plus concrete reads for
weight, steps, active energy and sleep. `HealthSnapshot` can represent height
and basal energy, but the concrete repository does not query them yet. The
HealthKit entitlement is temporarily empty for Personal Team device signing;
restore it with a paid Developer Program team. Observer queries and background
delivery are also still open.

**Phase 3** is a working gateway POC: an ordered nutrition repository has USDA
FoodData Central and Open Food Facts adapters with source provenance. They are
opt-in; the default 88-row Vietnamese table is explicitly marked as unsourced
reference data and must be replaced by a licensed, cited dataset before release.

**Phase 4** is implemented through capture/picker, normalized upload, gateway,
review/correction and confirmed save, and has run on a physical iPhone. A scan
that *fails* stays on the review screen with its photo and is finished by hand,
rather than ending on an error screen — that is a deviation from §6.7 and is
listed below. Gemini
is verified; Qwen and a representative evaluation dataset are still open. A
confirmed scan now also **keeps its photo** (§32 stage 2) — nothing else in the
app does, and no other flow can attach one.

**Phase 5 is complete**: calories, protein, carbohydrate, fat, **fibre and
water**. Fibre is only ever as good as its source, though, and today that source
is manual entry alone — the gateway returns none, so a user who logs by scanning
sees no fibre at all rather than a wrong figure. See the Fibre and water section.
Deterministic recommendations (Phase 6), personalization, CloudKit and on-device
inference are not present.

**§19's notifications are implemented** — the four budget thresholds, a meal
reminder and a daily summary, behind §6.13's five switches. See the Notifications
section for the two rules that are this repo's rather than the spec's.

**§22's correction record is complete** — the model's proposed weight *and* name
are stored beside what the user confirmed, so three of §29's four measures can be
read straight out of the store. §29's labelled evaluation set is still open, and
is a data-collection job rather than a coding one.

Deviations from `plan.md` already made:

- **The handoff's §4 bilingual labels are gone**, replaced by a language switch on
  Profile and a fully translated catalog. The two are alternatives, not additions:
  a bilingual label under an English UI prints "Step count / Step count". The
  handoff and `plan.md` still describe the bilingual UI and are not edited — they
  are the spec, not a log. See the Language section.
- `UserProfile` gains `biologicalSex` and `activityLevel` (§13 omitted them but
  Mifflin-St Jeor needs them).
- `UserRepository` is `load()` / `save(profile:goal:)` as one unit rather than
  four separate accessors, so a goal can never be stored without a profile.
- `HealthRepository` is one `snapshot(on:)` rather than §14's per-metric getters,
  so the dashboard makes a single call instead of six, and there is no
  `SyncHealthDataUseCase` — it would have been a pure passthrough.
- §6.12's "% AI cần sửa khẩu phần" counts renames as well as portion edits, and
  is labelled "kết quả AI phải sửa" to match. A rate that ignored renames would
  miss exactly the errors that matter most — a dish read as the wrong dish at
  high confidence, where the portion was never wrong.
- §19's four budget triggers become three switches: "target reached" governs
  `exceeded` as well, because §6.13 draws three and passing the target is not a
  second event. §19's times are unspecified and are 20:00 / 21:00 here.
- `Meal` gains `calorieGoalWhenLogged`, and `SaveMealUseCase` therefore takes the
  user repository as well as the meal one. §13's `Meal` is food and a date, which
  cannot answer "was that day over target" once the goal has changed — HISTORY_SPEC
  §8 needs the target of the day, so the day stores it.
- **Phase 5's water target is this repo's rule of thumb**, not a sourced value:
  35 ml/kg with a 1.500 ml floor. `plan.md` asks for "optional water tracking"
  and names no figure, and the published references measure something the app
  cannot (total water, including what comes from food). The fibre rule (14 g per
  1.000 kcal) *is* sourced. Both are marked as such in
  `CalculateCalorieGoalUseCase`.
- **§6.7's failure screen is deleted rather than restyled.** The handoff draws a
  dark screen with "Thử lại" and "Nhập tay"; both discarded the photo, so a
  failed analysis could not be logged at all. A failure now lands on §6.8's review
  screen with the photo, no items and a note, and the meal is typed in there. See
  "A failed analysis is not a dead end".
- **PROFILE_SPEC §5's weekly pace, manual goal and date of birth are not built**,
  and neither is its sex-based calorie floor: each needs `UserProfile` or
  `WeightGoal` to change, and the Domain layer is not reshaped to fit a screen.
  A "Hướng mục tiêu" row stands in for the pace control so the goal can still be
  changed. The Profile section has the detail, including the arithmetic error in
  the spec's own worked example.
