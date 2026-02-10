# Repository Guidelines

## Project Structure & Module Organization
- `Ida/` contains the iOS app target shell (`IdaApp.swift`, `AppIntents.swift`, `Info.plist`, entitlements, app-level assets/strings).
- `Modules/AppFeature/` contains the main feature module (views, SQLiteData schema/migrations, reminders, feature assets/strings).
- `Modules/AppFeatureTests/` contains unit tests for `AppFeature` using Swift Testing.
- `Modules/Package.swift` defines the local Swift package (`AppFeature`, `AppFeatureTests`) used by the app target.
- `Modules/AppFeature.xctestplan` defines the package test plan.
- `Ida.xcodeproj/` stores the app project and shared schemes (`Ida`, `Ida - Release`, `AppFeature`).
- `ci_scripts/` includes CI helper scripts used by Xcode Cloud.

## Build, Test, and Development Commands
Always use XcodeBuildMCP for local builds on the iPhone 17 simulator.
- Always use XcodeBuildMCP for debugging and app launching workflows (launch, log capture, screenshots, UI snapshots, stop/relaunch). Do not use non-MCP launch/debug flows.
- Boot iPhone 17 (once per session):
  - `mcp__XcodeBuildMCP__session_set_defaults` with `projectPath`, `scheme: "Ida"`, `simulatorId: 27444936-D9E5-4E28-B81C-762DFF92FD21`, `configuration: "Debug"`, `useLatestOS: true`
  - `mcp__XcodeBuildMCP__boot_sim`
- Build app:
  - `mcp__XcodeBuildMCP__build_sim`
- Build module scheme directly (optional):
  - `mcp__XcodeBuildMCP__session_set_defaults` with `scheme: "AppFeature"` (keep same project/simulator defaults)
  - `mcp__XcodeBuildMCP__build_sim`
- Test status (current setup):
  - `Ida` shared scheme is not configured with a test action.
  - `AppFeature` shared scheme exists, but `test_sim` currently reports no attached test bundles.
  - Tests live in `Modules/AppFeatureTests/` and `Modules/AppFeature.xctestplan`; wire these into a scheme test action before relying on CLI `test_sim`.
- Debug/launch/logging:
  - `mcp__XcodeBuildMCP__launch_app_sim`
  - `mcp__XcodeBuildMCP__launch_app_logs_sim`
  - `mcp__XcodeBuildMCP__start_sim_log_cap`
  - `mcp__XcodeBuildMCP__stop_sim_log_cap`
  - `mcp__XcodeBuildMCP__screenshot`
  - `mcp__XcodeBuildMCP__snapshot_ui`
Release builds still use the shared scheme:
- `xcodebuild -scheme "Ida - Release" -configuration Release build`

## Coding Style & Naming Conventions
- Swift and SwiftUI code in `Ida/` and `Modules/AppFeature/` uses 2-space indentation; follow existing formatting.
- Tests follow existing formatting.
- Types use PascalCase (e.g., `ChildDetailView`); properties and methods use camelCase.
- File names typically match the primary type in the file (e.g., `ChildListView.swift`).
- Add new feature UI strings to `Modules/AppFeature/Localizable.xcstrings`.
- Add app-intent/app-shell strings to `Ida/Localizable.xcstrings`.

## Testing Guidelines
- Unit tests in `Modules/AppFeatureTests/` use Swift Testing (`import Testing`).
- There is currently no UI test target in this repo; add one if UI coverage is needed.
- Name test files `*Tests.swift` and keep test methods small and focused.
- Use deterministic dependencies in suites (`.dependency(\.context, .test)`, `.dependency(\.date.now, ...)`, `.dependency(\.uuid, .incrementing)`).

## Refactor Learnings (ChildListModel)
- `ChildListView` logic in `Modules/AppFeature/ChildListView.swift` is extracted into `@MainActor @Observable` `ChildListModel`; keep the view focused on rendering and user-event forwarding.
- In `@Observable` models that use SQLiteData, annotate `@FetchAll`/`@FetchOne`/`@Fetch` and `@Dependency` properties with `@ObservationIgnored`.
- Keep model injection explicit in views (`init(model: ChildListModel = .init())`) to support targeted unit tests.
- For model tests, use `@Suite` traits with deterministic dependencies (`.dependency(\.context, .test)`, `.dependency(\.date.now, ...)`, `.dependency(\.uuid, .incrementing)`) and bootstrap via `.dependencies { try $0.bootstrapDatabase(seedData: false) }`.
- Keep feature logic testable in the package test target (`@testable import AppFeature`).

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
- If a test needs extra packages (e.g., `DependenciesTestSupport`), add the product to `Modules/Package.swift` under the `AppFeatureTests` target.

## Commit & Pull Request Guidelines
- Recent commits use short, imperative summaries (e.g., “Add search suggestions to add item”).
- Keep commit subjects under ~72 characters when possible.
- PRs should include a clear description, linked issues (if any), and screenshots for UI changes.

## Configuration & Capabilities
- CloudKit and entitlements live in `Ida/Ida.entitlements` and `Ida/Info.plist`; coordinate changes with the team.
- Database/bootstrap/sync configuration lives in `Modules/AppFeature/Schema.swift`.
- CI scripts in `ci_scripts/` adjust Xcode validation defaults; keep them in sync with CI needs.

## SQLiteData Reference (Point-Free)
- Docs: `https://swiftpackageindex.com/pointfreeco/sqlite-data/main/documentation/sqlitedata/` (Swift Package Index DocC).
- SQLiteData is a SwiftData-like API on top of SQLite (via GRDB); it uses value-type `@Table` models and property wrappers like `@FetchAll`/`@FetchOne` to fetch and observe data.
- Initialize `defaultDatabase` early (app entry) via `prepareDependencies`, then access it with `@Dependency(\.defaultDatabase)` for reads/writes.
- Writes go through `database.write { db in ... }` which wraps changes in a transaction; use `DatabaseMigrator` + `#sql` for schema/migrations.
- Optional CloudKit sync is configured by setting `defaultSyncEngine = SyncEngine(for:defaultDatabase, tables: ...)`.
- SQLite knowledge (schema design, queries, indexes) is expected for effective use.
- In this repo, see `Modules/AppFeature/Schema.swift` for migrations + sync setup and `Modules/AppFeature/ChildListView.swift` / `Modules/AppFeature/ItemFormView.swift` for fetch/write usage.
