# Repository Guidelines

## Project Structure & Module Organization

HeathFirst is an iOS 17+ SwiftUI app with a separate SwiftPM domain module. Keep business rules in `Sources/Domain/` (`Entities`, `UseCases`, and repository protocols); this layer may import only Swift standard-library modules and Foundation. App composition, SwiftUI presentation, SwiftData adapters, HealthKit, and recognition gateways live under `App/`. Domain tests are in `Tests/DomainTests/`, while end-to-end XCUITests are in `AppUITests/`. Configuration and entitlements belong in `Config/`; fonts and asset catalogs belong in `App/Resources/`. Treat `design_handoff_healthclean/` and `plan.md` as product/design references, not runtime code.

Files added beneath `App/` or `AppUITests/` are discovered by Xcode's file-system-synchronized groups; do not manually add project-file references.

## Build, Test, and Development Commands

- `swift build` compiles the `Domain` library without launching a simulator.
- `swift test` runs the fast Swift Testing domain suite.
- `swift test --filter "macros re-sum"` runs a focused domain test by display name.
- `xcodebuild -scheme HeathFirst -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` builds the app.
- Replace `build` with `test` to run domain and UI tests through Xcode. For one UI test, add `-only-testing:HeathFirstUITests/Phase1FlowTests/testLoggingAMealMovesTheDashboard`.

Open `HeathFirst.xcodeproj` for normal simulator or device development. Prefer `swift test` for domain-only changes; use `xcodebuild` whenever `App/`, configuration, or UI behavior changes.

## Coding Style & Naming Conventions

Follow existing Swift style: four-space indentation, one primary type per file, `UpperCamelCase` types, and `lowerCamelCase` members. Name files after their primary type, such as `CalculateBMIUseCase.swift`. Preserve the dependency direction: View -> observable model -> use case -> repository protocol -> data implementation. Use `DS.*` design tokens instead of hard-coded colors, spacing, or radii. No formatter or linter is configured, so match neighboring code and keep compiler warnings clean.

## Testing Guidelines

Use Swift Testing (`@Suite`, `@Test`, `#expect`) for domain behavior and XCTest for UI flows. Name domain files `*Tests.swift` and UI methods `test...`. Use `expectClose` for `Double` assertions and fixed dates instead of `Date()`. UI tests must launch with `-uiTesting` and query stable `accessibilityIdentifier` values, not localized labels. Add boundary tests for calorie and warning logic.

## Commit & Pull Request Guidelines

Use Commitizen-compatible Conventional Commits, matching history: `feat(scan): ...`, `fix(ui): ...`, or `docs: ...`. Keep each commit focused and written in the imperative mood. Pull requests should explain user-visible behavior, list verification commands, link the relevant issue or plan section, and include before/after screenshots for UI changes. Call out entitlement, signing, persistence, or localization changes explicitly.
