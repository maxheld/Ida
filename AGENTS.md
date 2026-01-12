# Repository Guidelines

## Project Structure & Module Organization
- `Ida/` contains the SwiftUI app sources (views, models, app entry, `Info.plist`).
- `Ida/Schema.swift` defines the SQLiteData tables, migrations, and CloudKit sync bootstrap.
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
- Tests follow existing formatting (UI tests currently use Xcode’s default 4-space indentation).
- Types use PascalCase (e.g., `ChildDetailView`); properties and methods use camelCase.
- File names typically match the primary type in the file (e.g., `ChildListView.swift`).
- Add new localized strings to `Ida/Localizable.xcstrings` and reference them via `Text` or `LocalizedStringKey`.

## Testing Guidelines
- Unit tests in `IdaTests/` use Swift Testing (`import Testing`).
- UI tests in `IdaUITests/` use XCTest (`import XCTest`).
- Name test files `*Tests.swift` and keep test methods small and focused.
- Prefer running `xcodebuild test` before opening a PR.

## SQLiteData Testing Notes
- Follow the sqlite-data Examples tests as the canonical style guide:
  - `Examples/RemindersTests/Internal.swift` (base suite + dependency setup)
  - `Examples/SyncUpTests/SyncUpFormTests.swift` (database usage in tests)
- Use `DependenciesTestSupport` + `@Suite` traits to prepare test dependencies:
  - `.dependency(\.context, .test)`
  - `.dependency(\.date.now, ...)`
  - `.dependency(\.uuid, .incrementing)`
  - `.dependencies { try $0.bootstrapDatabase(seedData: true) }`
- In tests, rely on `@Dependency(\.defaultDatabase)` and app-layer APIs/queries rather than duplicating schema or writing low-level SQL migrations.
- For empty-database scenarios, override per test with a suite/test dependency: `.dependencies { try $0.bootstrapDatabase(seedData: false) }`.
- If a test needs extra packages (e.g., `DependenciesTestSupport`), add the product to the `IdaTests` target in `Ida.xcodeproj`.

## Commit & Pull Request Guidelines
- Recent commits use short, imperative summaries (e.g., “Add search suggestions to add item”).
- Keep commit subjects under ~72 characters when possible.
- PRs should include a clear description, linked issues (if any), and screenshots for UI changes.

## Configuration & Capabilities
- CloudKit and entitlements live in `Ida/Ida.entitlements` and `Ida/Info.plist`; coordinate changes with the team.
- CI scripts in `ci_scripts/` adjust Xcode validation defaults; keep them in sync with CI needs.

## SQLiteData Reference (Point-Free)
- Docs: `https://swiftpackageindex.com/pointfreeco/sqlite-data/main/documentation/sqlitedata/` (Swift Package Index DocC).
- SQLiteData is a SwiftData-like API on top of SQLite (via GRDB); it uses value-type `@Table` models and property wrappers like `@FetchAll`/`@FetchOne` to fetch and observe data.
- Initialize `defaultDatabase` early (app entry) via `prepareDependencies`, then access it with `@Dependency(\.defaultDatabase)` for reads/writes.
- Writes go through `database.write { db in ... }` which wraps changes in a transaction; use `DatabaseMigrator` + `#sql` for schema/migrations.
- Optional CloudKit sync is configured by setting `defaultSyncEngine = SyncEngine(for:defaultDatabase, tables: ...)`.
- SQLite knowledge (schema design, queries, indexes) is expected for effective use.
- In this repo, see `Ida/Schema.swift` for migrations + sync setup and `Ida/ChildListView.swift` / `Ida/ItemFormView.swift` for fetch/write usage.
