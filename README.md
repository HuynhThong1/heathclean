# HeathFirst

Phase 1 of the calorie tracker described in [`plan.md`](plan.md): profile, BMI,
personalized calorie and macro targets, manual meal entry, meal history, daily
dashboard, and the warning engine. No AI, no HealthKit — those are Phases 2–4.

## Layout

```
Package.swift          SwiftPM package "HeathFirstKit"
Sources/Domain/        pure Swift — entities, use cases, repository protocols
Sources/DomainCheck/   executable check runner for the Domain layer
App/                   the iOS app target (SwiftData + SwiftUI)
```

The Domain layer is a separate SwiftPM module so the compiler enforces
`plan.md` §11: it imports nothing but the Swift standard library and
Foundation. `App/` depends on it, never the other way round.

## Verifying the Domain layer

This works with Command Line Tools alone — no Xcode required:

```bash
swift build
swift run DomainCheck
```

`DomainCheck` prints one line per check and exits non-zero if any fail. It
covers BMI values and category boundaries, the Mifflin-St Jeor variants,
activity multipliers, goal offsets, both calorie floors, the macro split, every
warning threshold boundary, and meal/summary aggregation.

Once Xcode is installed, replace it with a real `Tests/DomainTests` target
using `import Testing` and `#expect` — the assertions translate one for one —
and delete `Sources/DomainCheck/`. It exists only because neither `XCTest` nor
`Testing` ships with the Command Line Tools.

## Building the app

`App/` has no `.xcodeproj` yet — it could not be generated or verified on a
machine without Xcode. To wire it up:

1. Create a new iOS App target named `HeathFirst`, minimum deployment iOS 17.
2. Delete the generated `ContentView.swift` and `*App.swift`; add the `App/`
   directory to the target instead.
3. **File → Add Package Dependencies… → Add Local…** and select this repo's
   root, then add the `Domain` library product to the target.
4. Build and run:

```bash
xcodebuild -scheme HeathFirst \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

No Info.plist entries are needed for Phase 1; HealthKit usage strings arrive
with Phase 2.

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
