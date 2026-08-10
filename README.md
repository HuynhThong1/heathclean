    # HeathFirst

Phase 1 of the calorie tracker described in [`plan.md`](plan.md): profile, BMI,
personalized calorie and macro targets, manual meal entry, meal history, daily
dashboard, and the warning engine. No AI, no HealthKit — those are Phases 2–4.

## Layout

```
Package.swift          SwiftPM package "HeathFirstKit"
Sources/Domain/        pure Swift — entities, use cases, repository protocols
Tests/DomainTests/     swift-testing suites
App/                   the iOS app target (SwiftData + SwiftUI)
AppUITests/            XCUITest walkthrough of the Phase 1 flow
HeathFirst.xcodeproj   iOS 17+ app target, consumes the local package
```

The Domain layer is a separate SwiftPM module so the compiler enforces
`plan.md` §11: it imports nothing but the Swift standard library and
Foundation. `App/` depends on it, never the other way round.

## Running the tests

```bash
swift test                                  # 25 Domain tests, no simulator needed

xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The Domain suite covers BMI values and category boundaries, the Mifflin-St Jeor
variants, activity multipliers, goal offsets, both calorie floors, the macro
split, every warning threshold boundary, and meal/summary aggregation.

The UI suite drives the real app: onboarding produces the expected target,
logging a meal moves the dashboard, and crossing 70% / 100% surfaces the
warning copy.

## Building and running the app

```bash
xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Or open `HeathFirst.xcodeproj` and run. No Info.plist entries are needed for
Phase 1; HealthKit usage strings arrive with Phase 2.

The project file uses file-system-synchronized groups, so files added under
`App/` or `AppUITests/` are picked up with no project edits.

## Calorie model

Targets come from age, height, weight, sex, activity level and goal — never
from BMI, which is shown as health context only.

- **BMR** — Mifflin-St Jeor. An unspecified sex uses the midpoint of the male
  (+5) and female (−161) constants, and the onboarding screen says so.
- **TDEE** — BMR × activity multiplier (1.2 … 1.9).
- **Goal** — lose −500 kcal/day, maintain 0, gain +350.
- **Floor** — `max(adjusted, max(BMR, 1200))`. A deficit never prescribes below
  the user's own basal rate. For sedentary users this can shrink the intended
  deficit; that is deliberate.
- **Macros** — protein 1.8 g/kg when losing, otherwise 1.6 g/kg; fat 25% of
  energy; carbohydrates take the remainder.
