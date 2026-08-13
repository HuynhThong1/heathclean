# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build            # compiles the Domain library
swift test             # 30 Domain tests (swift-testing) — fast, no simulator

xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # + 5 UI tests
```

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

### Rules

- Use `DesignTokens.swift` (`DS.*`) for every colour / radius / spacing /
  motion. Never hardcode a hex in a View.
- Do not change the Domain layer to fit the UI. The UI reads
  `CalculateCalorieGoalUseCase` and `EvaluateCalorieBudgetUseCase`.
- Blue `#0062B0` leads. Orange `#F37021` is reserved for the scan action alone.
  Green `#12B24C` is growth/success only.
- Over-budget state is **neutral grey, never red, never a command.** This is a
  health app for casual users, not a scold.
- Every label is bilingual: Vietnamese primary (14.5px/650) with English beneath
  (11.5px, `textSubtle`). Use `LabelPair`.
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

Profile omits §6.13's five notification switches: there is no notification
system, and a switch that schedules nothing is a broken control. Add them with
UserNotifications, not before. It also shows a generic avatar rather than
initials, because nothing in the app ever asks for a name.

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

Two of §6.12's four stat cells are deliberately absent:

- "% bữa ăn được ghi" has no denominator — the app never learns how many meals
  the user meant to eat, and any figure would be invented.
- "% AI cần sửa khẩu phần" is not recorded. `FoodItem` keeps `aiConfidence`, so
  the app knows which items came from a scan, but not whether the user corrected
  the portion. Recording that means adding a field at the point of confirmation.

The closing gray note of §6.12 is also absent; it needs an analysis of
afternoon protein that nothing specifies.

Hiding the navigation bar also hides the system back button, so any screen that
draws its own header must supply `HFBackChip` — edge-swipe is not a visible
affordance. This applies to pushed and sheet-presented screens; tab roots do not
need one. Apple Health still uses it.

The §5 tab bar is complete: all four roots — Hôm nay, Lịch sử, Thống kê, Tôi —
plus the raised orange scan action between History and Insights. One thing §5
specifies is still absent: Welcome's "Tôi đã có tài khoản" link, because there is
no account system to sign into and a link that cannot do what it says is worse
than none. A tab that opens nothing is worse than an absent one.

### The history week strip — not in the handoff

§6.11 draws History as a plain scroll of day sections. `HistoryWeekStrip` was
added on top of that and **changes what the screen shows: one day, not a month.**
It is the reason `MealHistoryModel` no longer has `days`.

- The loaded window is **exactly the week on screen** — `meals(from: weekStart,
  to: weekStart + 7d)`. That is what makes the dots cheap, and it is also why
  there is only one empty-state message: with a one-week window the app cannot
  tell "never logged anything" from "nothing this week" without a second query,
  so today says "Hôm nay chưa ghi bữa nào…" and any other day says "Ngày này
  không có bữa ăn nào được ghi."
- The model builds its own **Monday-first** `Calendar` (`firstWeekday = 2`).
  `Calendar.current` starts the week on Sunday under a US locale, which would put
  CN in the first column while the labels still read T2…CN.
- A dot under a day means **that day has meals**. No meals, no dot — never a
  hollow placeholder, the same reason `WeightPoint.weekIndex` leaves gaps as gaps.
- **Future days are dimmed and `.disabled`, and `canGoForward` is false once the
  visible week holds today.** History is a record; a cell that can never hold a
  meal must not be tappable, and there is no week ahead to page into.
- `load()` pins the week it was asked for and **drops its result if the week
  changed while it was in flight.** Tapping ‹ faster than SwiftData answers
  starts a second load, and nothing orders two `@ModelActor` calls — the slower
  one landing last would leave the dots describing a week no longer on screen.
- There is deliberately **no date pill** like the reference design's "31 August
  ›". Without a month-grid sheet it would open nothing, and the day row beneath
  ("Thứ Tư 12/8") already carries that text.
- `HistoryWeekStrip.identifier(for:)` builds `yyyy-MM-dd` from date components
  rather than a `DateFormatter`: it runs once per cell per render, and the
  formatter cannot be cached in a `static let` (not `Sendable`), so it would be
  constructed seven times a pass.
- `VietnameseDate.weekdayShort` duplicates three lines inside `InsightsView` on
  purpose. The Insights copy returns "Nay" for today; the strip must not, because
  a wider label on one of seven fixed columns shifts the whole row.

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

**`Config/Info.plist` carries an `NSExceptionDomains` entry with a placeholder
address (`203.0.113.10`), and until it is replaced with the real VPS IP the
scan fails as a network error.** `NSAllowsLocalNetworking` covers the Mac on
the same Wi-Fi and nothing public, so a plaintext gateway on a public address
needs its own exception, matched on the exact literal. It is scaffolding for
testing against an IP: the key crosses the wire in clear text, so give the
gateway a domain and a certificate and delete the whole dict.
`NSAllowsArbitraryLoads` is the wrong tool — it disables ATS for every host the
app will ever contact, to fix one.

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

**The scan flow is the one place the app goes dark.** §6.6 (camera), §6.7
(analysing) and §6.7's failure state all sit on `DS.scanSurface`; §6.8 (review)
returns to the light surface, which is what the handoff draws. `DS.scanSurface`
and `DS.scanViewfinder` live beside the camera code rather than in
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

None of this path has a UI test: reaching §6.8 means driving the system Photos
sheet, which the suite avoids for the same reason it avoids the HealthKit sheet.
`MockFoodRecognitionRepository` does return one unresolved food, so the path is
exercisable by hand on a simulator.

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
line — must be wrapped in `String(localized:)` or it silently stays out of the
catalog.

**No translations have been added, deliberately.** §4 makes the UI *bilingual*:
`LabelPair` shows Vietnamese and English at once, by design. That is not the
same as switching language, and nothing in the handoff asks for a language
switch — adding an `en` locale would turn "Bước chân / Step count" into
"Step count / Step count" on an English device. The catalog exists so copy can
be edited without touching Swift, and so translation is possible when someone
decides what it should mean.

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
values are real.

A language switch is **not** part of this and should not be added casually: §4's
`LabelPair` shows Vietnamese and English *at the same time*, so "English mode"
would render "Step count / Step count" unless `LabelPair` is redesigned to show
one language — which changes every screen. The catalog also still has 140 keys
and only a `vi` locale, so there is nothing to switch to yet. It needs a design
decision first, not a toggle.

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
review/correction and confirmed save, and has run on a physical iPhone. Gemini
is verified; Qwen and a representative evaluation dataset are still open.

**Phase 5** has calories plus protein/carbohydrate/fat tracking. Fiber and water
are not present. Notifications, deterministic recommendations, personalization,
CloudKit and on-device inference are also not present.

Deviations from `plan.md` already made:

- `UserProfile` gains `biologicalSex` and `activityLevel` (§13 omitted them but
  Mifflin-St Jeor needs them).
- `UserRepository` is `load()` / `save(profile:goal:)` as one unit rather than
  four separate accessors, so a goal can never be stored without a profile.
- `HealthRepository` is one `snapshot(on:)` rather than §14's per-metric getters,
  so the dashboard makes a single call instead of six, and there is no
  `SyncHealthDataUseCase` — it would have been a pure passthrough.
