# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build            # compiles the Domain library
swift test             # 25 Domain tests (swift-testing) — fast, no simulator

xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # + 4 UI tests
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

### SwiftUI gotcha already hit once

A `Button` with `.buttonStyle(.plain)` wrapping a `LabeledContent` only hit-tests
where text is drawn — the gap between label and value is dead space. Add
`.contentShape(Rectangle())` to the label. The dashboard meal rows do this.

## Scope

`plan.md` is the product spec — 31 sections, 8 phases. It is the source of truth and
should not be edited as a side effect of implementation work.

Only **Phase 1** is built: profile, BMI, calorie/macro targets, manual meal entry,
meal history, dashboard, warning engine, SwiftData. Explicitly not present and not
to be added without being asked: HealthKit, camera/AVFoundation, any AI provider,
nutrition APIs (USDA, Open Food Facts), notifications, CloudKit.

Two deviations from `plan.md` already made: `UserProfile` gains `biologicalSex` and
`activityLevel` (§13 omitted them but Mifflin-St Jeor needs them), and
`UserRepository` is `load()` / `save(profile:goal:)` as one unit rather than four
separate accessors, so a goal can never be stored without a profile.
