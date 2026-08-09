# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Toolchain constraint — read this first

This machine has **Command Line Tools only, no Xcode**. Verified limits:

| | |
| --- | --- |
| `swift build` / `swift run` on `Sources/` | works |
| `swift test` | **impossible** — neither `XCTest` nor `Testing` is in the CLT SDK |
| SwiftData `@Model` | **impossible** — the `SwiftDataMacros` plugin is not shipped with CLT |
| iOS SDK, simulator, `xcodebuild` | absent — macOS SDKs only |

Consequence: `Sources/` can be compiled and executed; **`App/` cannot be compiled at
all**. Never report anything under `App/` as working or verified. Say it is unverified.

## Commands

```bash
swift build            # compiles Domain + DomainCheck
swift run DomainCheck  # the test suite; exits non-zero on any failure
```

There is no `swift test`. `Sources/DomainCheck/` is a hand-rolled assert runner that
exists solely because no test framework is installable here. It is the success
criterion for any Domain change — a change is not done until it exits 0.

To run a subset, comment out the relevant `run*Checks(runner)` call in
`Sources/DomainCheck/main.swift`; there is no filter flag.

Once Xcode is installed, convert `Sources/DomainCheck/` to a `Tests/DomainTests`
target using `import Testing` / `#expect` (the assertions map one for one), delete
the harness, and switch verification to `swift test`.

## Architecture

Clean Architecture with the dependency rule enforced by the module boundary rather
than by convention:

```
Sources/Domain/   SwiftPM library — pure Swift, imports only stdlib + Foundation
Sources/DomainCheck/  executable check runner, depends on Domain
App/              iOS app target — SwiftData + SwiftUI, depends on Domain
```

`Domain` must never import SwiftUI, SwiftData, HealthKit, CoreML, or AVFoundation.
Because it is a separate module, a violation is a compile error, not a review catch.
Keep it that way.

`App/` has **no `.xcodeproj`** — it could not be generated without Xcode. `README.md`
has the steps to create the target and link the local package.

### Data flow

SwiftUI view → `@Observable` model (`App/Presentation/*/`) → use case
(`Sources/Domain/UseCases/`) → repository protocol
(`Sources/Domain/Repositories/`) → `@ModelActor` implementation
(`App/Data/Local/SwiftData/`).

`@Model` classes exist only in the Data layer and convert to Domain structs at the
repository boundary via `entity.meal` / `entity.profile` style computed properties.
SwiftData types never travel upward. `DependencyContainer` is the single place
protocols are bound to implementations and models are constructed.

### Calorie model — the non-obvious parts

`CalculateCalorieGoalUseCase` derives everything from age, height, weight, sex,
activity and goal. BMI is deliberately **not** an input; it is health context only.

- BMR is Mifflin-St Jeor. An unspecified or `preferNotToSay` sex uses −78, the
  midpoint of the male (+5) and female (−161) constants.
- Floor: `max(adjusted, max(BMR, 1200))`. A deficit never prescribes below the
  user's own basal rate. **This visibly weakens the deficit for sedentary users**
  (reference profile gets 1780 kcal instead of 1636) and is intentional; the
  `calorieGoal/deficit-clamped-to-bmr` check pins it.
- Macros: protein 1.8 g/kg when losing else 1.6 g/kg, fat 25% of energy,
  carbohydrates take the remainder. They re-sum to the calorie target exactly.

Warning thresholds (`EvaluateCalorieBudgetUseCase`) are boundary-sensitive:
`<0.70 normal`, `≥0.70 informUser`, `≥0.90 nearTarget`, `≥1.00 reached`,
`>1.00 exceeded`. Message copy stays neutral and informative by design — `plan.md`
§18 explicitly rules out instructing the user whether to eat.

### DomainCheck conventions

- Use `expectClose` for every `Double`; `expect` is exact equality only. They are
  separate names on purpose, so a float can never silently take the exact path.
- The runner and all `run*Checks` functions are `@MainActor` — async closures
  crossing to a nonisolated function trip Swift 6 sendability errors.
- Fixtures live in `Sources/DomainCheck/Fixtures.swift`. `makeProfile()` defaults to
  male, 80 kg, 180 cm, 30 y → BMR exactly 1780, which most expected values assume.
- `referenceDate` is a fixed instant; do not introduce `Date()` into checks.

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
