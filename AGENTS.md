# Repository Guidelines

## Project Structure & Module Organization
- `Ida/` contains the SwiftUI app sources (views, models, app entry, `Info.plist`).
- `Ida/Schema.swift` defines the SQLiteData tables, migrations, and CloudKit sync bootstrap.
- `Ida/Assets.xcassets/` holds app icons and color assets.
- `Ida/Localizable.xcstrings` defines localized strings used across the UI.
- `IdaTests/` contains unit tests.
- `Ida.xcodeproj/` stores the Xcode project and shared schemes.
- `ci_scripts/` includes CI helper scripts used by Xcode Cloud.

## Build, Test, and Development Commands
Always use XcodeBuildMCP for local builds on the iPhone 17 simulator.
- Always use XcodeBuildMCP for debugging and app launching workflows (launch, log capture, screenshots, UI snapshots, stop/relaunch). Do not use non-MCP launch/debug flows.
- Boot iPhone 17 (once per session):
  - `mcp__xcodebuildmcp__session-set-defaults` with `projectPath`, `scheme: "Ida"`, `simulatorId: 27444936-D9E5-4E28-B81C-762DFF92FD21`, `configuration: "Debug"`, `useLatestOS: true`
  - `mcp__xcodebuildmcp__boot_sim`
- Build:
  - `mcp__xcodebuildmcp__build_sim`
- Test (if needed):
  - `mcp__xcodebuildmcp__test_sim`
- Debug/launch/logging:
  - `mcp__xcodebuildmcp__launch_app_sim`
  - `mcp__xcodebuildmcp__launch_app_logs_sim`
  - `mcp__xcodebuildmcp__start_sim_log_cap`
  - `mcp__xcodebuildmcp__stop_sim_log_cap`
  - `mcp__xcodebuildmcp__screenshot`
  - `mcp__xcodebuildmcp__snapshot_ui`
Release builds still use the shared scheme:
- `xcodebuild -scheme "Ida - Release" -configuration Release build`

## Coding Style & Naming Conventions
- Swift and SwiftUI code in `Ida/` uses 2-space indentation; follow existing formatting.
- Tests follow existing formatting.
- Types use PascalCase (e.g., `ChildDetailView`); properties and methods use camelCase.
- File names typically match the primary type in the file (e.g., `ChildListView.swift`).
- Add new localized strings to `Ida/Localizable.xcstrings` and reference them via `Text` or `LocalizedStringKey`.

## Testing Guidelines
- Unit tests in `IdaTests/` use Swift Testing (`import Testing`).
- There is currently no UI test target in this repo; add one if UI coverage is needed.
- Name test files `*Tests.swift` and keep test methods small and focused.
- Prefer running `mcp__xcodebuildmcp__test_sim` before opening a PR.

## Refactor Learnings (ChildListModel)
- `ChildListView` logic is extracted into `@MainActor @Observable` `ChildListModel`; keep the view focused on rendering and user-event forwarding.
- In `@Observable` models that use SQLiteData, annotate `@FetchAll`/`@FetchOne`/`@Fetch` and `@Dependency` properties with `@ObservationIgnored`.
- Keep model injection explicit in views (`init(model: ChildListModel = .init())`) to support targeted unit tests.
- For model tests, use `@Suite` traits with deterministic dependencies (`.dependency(\.context, .test)`, `.dependency(\.date.now, ...)`, `.dependency(\.uuid, .incrementing)`) and bootstrap via `.dependencies { try $0.bootstrapDatabase(seedData: false) }`.
- Keep app module importable in tests as `Ida` by setting `PRODUCT_MODULE_NAME = Ida` in app target build settings.
- Keep `IdaTests` `TEST_HOST` aligned with the real app bundle/executable name (`Ida: Baby Activity Logger.app` / `Ida: Baby Activity Logger`) to avoid host resolution failures.

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
