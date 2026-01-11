# Repository Guidelines

## Project Structure & Module Organization
- `Ida/` contains the SwiftUI app sources (views, models, app entry, `Info.plist`).
- `Ida/Assets.xcassets/` holds app icons and color assets.
- `Ida/Localizable.xcstrings` defines localized strings used across the UI.
- `IdaTests/` contains unit tests; `IdaUITests/` contains UI tests.
- `Ida.xcodeproj/` stores the Xcode project and shared schemes.
- `ci_scripts/` includes CI helper scripts used by Xcode Cloud.

## Build, Test, and Development Commands
- `xcodebuild -scheme Ida -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`
  - Builds the app for the simulator.
- `xcodebuild test -scheme Ida -destination 'platform=iOS Simulator,name=iPhone 15'`
  - Runs unit and UI tests.
- `xcodebuild -scheme "Ida - Release" -configuration Release build`
  - Produces a release build using the shared release scheme.

## Coding Style & Naming Conventions
- Swift and SwiftUI code in `Ida/` uses 2-space indentation; follow existing formatting.
- Types use PascalCase (e.g., `ChildDetailView`); properties and methods use camelCase.
- File names typically match the primary type in the file (e.g., `ChildListView.swift`).
- Add new localized strings to `Ida/Localizable.xcstrings` and reference them via `Text` or `LocalizedStringKey`.

## Testing Guidelines
- Tests use Swift Testing (`import Testing`) in `IdaTests/` and `IdaUITests/`.
- Name test files `*Tests.swift` and keep test methods small and focused.
- Prefer running `xcodebuild test` before opening a PR.

## Commit & Pull Request Guidelines
- Recent commits use short, imperative summaries (e.g., “Add search suggestions to add item”).
- Keep commit subjects under ~72 characters when possible.
- PRs should include a clear description, linked issues (if any), and screenshots for UI changes.

## Configuration & Capabilities
- CloudKit and entitlements live in `Ida/Ida.entitlements` and `Ida/Info.plist`; coordinate changes with the team.
- CI scripts in `ci_scripts/` adjust Xcode validation defaults; keep them in sync with CI needs.
