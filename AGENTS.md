# Repository Guidelines

## Project Structure & Module Organization
- `Ida/` contains the iOS app target shell (`IdaApp.swift`, `AppIntents.swift`, `Info.plist`, entitlements, app-level assets/strings).
- `Modules/AppFeature/` contains the main feature module (views, SQLiteData schema/migrations, reminders, feature assets/strings).
- Core feature files currently include `ChildList.swift`, `ChildDetail.swift`, and `ItemFormView.swift` (view + model extractions).
- `Modules/AppFeatureTests/` contains unit tests for `AppFeature` using Swift Testing.
- `Modules/Package.swift` defines the local Swift package (`AppFeature`, `AppFeatureTests`) used by the app target.
- `Modules/AppFeature.xctestplan` defines the package test plan.
- `Ida.xcworkspace/` is the default entry point for local builds/tests and uses the shared schemes (`Ida`, `Ida - Release`, `AppFeature`, `AppFeatureTests`).
- `Modules/.swiftpm/xcode/xcshareddata/xcschemes/AppFeatureTests.xcscheme` is a committed package-level scheme for running `AppFeature` tests via XcodeBuildMCP without extra args.
- If SwiftPM regenerates package schemes in `Modules/.swiftpm/xcode/xcshareddata/xcschemes/`, keep `AppFeatureTests.xcscheme` present alongside `AppFeature.xcscheme`.
- `ci_scripts/` includes CI helper scripts used by Xcode Cloud.

## Build, Test, and Development Commands
Always use XcodeBuildMCP for local builds on the iPhone 17 simulator.
- Always use XcodeBuildMCP for debugging and app launching workflows (launch, log capture, screenshots, UI snapshots, stop/relaunch). Do not use non-MCP launch/debug flows.
- Boot iPhone 17 (once per session):
  - `mcp__XcodeBuildMCP__session_set_defaults` with `workspacePath: "Ida.xcworkspace"`, `scheme: "Ida"`, `simulatorId: 27444936-D9E5-4E28-B81C-762DFF92FD21`, `configuration: "Debug"`, `useLatestOS: true`
  - `mcp__XcodeBuildMCP__boot_sim`
- Build app:
  - `mcp__XcodeBuildMCP__build_sim`
- Build module scheme directly (optional):
  - `mcp__XcodeBuildMCP__session_set_defaults` with `scheme: "AppFeature"` (keep same workspace/simulator defaults)
  - `mcp__XcodeBuildMCP__build_sim`
- Run package tests (default):
  - `mcp__XcodeBuildMCP__session_set_defaults` with `scheme: "AppFeatureTests"` (keep same workspace/simulator defaults)
  - `mcp__XcodeBuildMCP__test_sim`
- Test status (current setup):
  - `Ida` shared scheme is not configured with a test action.
  - `AppFeature` and `AppFeatureTests` both run the package tests when using `workspacePath: "Ida.xcworkspace"`.
  - `AppFeatureTests` is the preferred MCP test scheme for clarity.
- Debug/launch/logging:
  - `mcp__XcodeBuildMCP__launch_app_sim`
  - `mcp__XcodeBuildMCP__launch_app_logs_sim`
  - `mcp__XcodeBuildMCP__start_sim_log_cap`
  - `mcp__XcodeBuildMCP__stop_sim_log_cap`
  - `mcp__XcodeBuildMCP__screenshot`
  - `mcp__XcodeBuildMCP__snapshot_ui`
Release builds still use the shared scheme:
- `xcodebuild -workspace Ida.xcworkspace -scheme "Ida - Release" -configuration Release build`

## Acknowledgements Maintenance
- `ACKNOWLEDGEMENTS.md` is a symlink to `Modules/AppFeature/Resources/ACKNOWLEDGEMENTS.md`.
- Generate acknowledgements with `tools/generate-third-party-acknowledgements.sh`; by default it writes `Modules/AppFeature/Resources/ACKNOWLEDGEMENTS.md` (accepts an optional explicit output path argument).
- Regenerate acknowledgements whenever `Modules/Package.resolved` `originHash` changes.
- Keep this tracked value updated whenever acknowledgements are regenerated (the generator updates this line automatically):
  - Last acknowledged `originHash`: `a55a115916a0d5b81ae345d4d9e79311ac88588865f26e67d55d202f90e9a06c`

## Swift LSP Code Reading
- Use `tools/sourcekit-lsp-query.sh` for semantic Swift inspection (symbols/hover/definition) before relying on plain text-only reads.
- Run all LSP queries from repo root and set workspace to `.` so paths resolve consistently.
- If `sourcekit-lsp` closes unexpectedly in sandboxed execution, rerun the same command outside sandbox/escalated mode.
- Single-file usage:
  - `tools/sourcekit-lsp-query.sh --workspace . symbols Modules/AppFeature/ChildList.swift`
  - `tools/sourcekit-lsp-query.sh --workspace . hover Modules/AppFeature/ChildList.swift 31 8`
  - `tools/sourcekit-lsp-query.sh --workspace . definition Modules/AppFeature/ChildList.swift 31 8`
- Batch mode (one long-lived LSP session for many files):
  - `tools/sourcekit-lsp-query.sh --workspace . symbols Modules/AppFeature/ChildList.swift Modules/AppFeature/ChildDetail.swift Modules/AppFeature/ItemFormView.swift`
  - `rg --files -g '*.swift' | xargs tools/sourcekit-lsp-query.sh --workspace . symbols`
- Persistent cache reuse (faster repeated runs):
  - Defaults already persist to `.lsp/scratch` and `.lsp/generated`.
  - Optional override: `tools/sourcekit-lsp-query.sh --workspace . --scratch-path .lsp/custom-scratch --generated-files-path .lsp/custom-generated symbols Modules/AppFeature/ChildList.swift`
- Incremental mode (changed Swift files only):
  - `tools/sourcekit-lsp-query.sh --workspace . --changed-only symbols`
  - `tools/sourcekit-lsp-query.sh --workspace . --changed-only --base-ref origin/main symbols`
- JSONL output for large/batch runs:
  - `tools/sourcekit-lsp-query.sh --workspace . --jsonl symbols Modules/AppFeature/ChildList.swift Modules/AppFeature/ChildDetail.swift`
  - `tools/sourcekit-lsp-query.sh --workspace . --jsonl-path .lsp/sourcekit-results.jsonl --changed-only symbols`
- Module-based parallelism (2-4 workers, long-lived LSP per worker):
  - `tools/sourcekit-lsp-query.sh --workspace . --workers 3 symbols Ida/IdaApp.swift Modules/AppFeature/ChildList.swift Modules/AppFeatureTests/ChildListModelTests.swift`
  - For repo-wide scans, prefer `--workers 2`, `--workers 3`, or `--workers 4` based on machine load.

## Coding Style & Naming Conventions
- Swift and SwiftUI code in `Ida/` and `Modules/AppFeature/` uses 2-space indentation; follow existing formatting.
- Tests follow existing formatting.
- Types use PascalCase (e.g., `ChildDetailView`); properties and methods use camelCase.
- File names usually follow feature grouping and may contain both view and model types (e.g., `ChildList.swift`, `ChildDetail.swift`).
- Prefer keeping behavior local to the feature context, even if that means longer functions or larger files, when extracting/reusing code would increase the chance of accidental calls or unintended triggering.
- For SwiftUI controls that support tinting (for example `Toggle`, `Picker`, and relevant control styles), always apply `.tint(.accentColor)` to keep interaction color consistent with the app.
- Add new feature UI strings to `Modules/AppFeature/Localizable.xcstrings`.
- Add app-intent/app-shell strings to `Ida/Localizable.xcstrings`.
- In non-main targets (for example `Modules/AppFeature`), always pass `bundle: .module` to `String(localized:)`.

## Testing Guidelines
- Always add tests for any new functionality; no feature work is complete without corresponding tests.
- Test suites must be exhaustive and prove intended behavior across happy paths, edge cases, and failure paths.
- Prioritize high assertion coverage (strong, behavior-focused assertions in each test). Treat raw code coverage as a secondary metric.
- Unit tests in `Modules/AppFeatureTests/` use Swift Testing (`import Testing`).
- There is currently no UI test target in this repo; add one if UI coverage is needed.
- Name test files `*Tests.swift` and keep test methods small and focused.
- Use deterministic dependencies in suites (`.dependency(\.context, .test)`, `.dependency(\.date.now, ...)`, `.dependency(\.uuid, .incrementing)`).

## Refactor Learnings (Observable Models)
- `ChildListView` logic in `Modules/AppFeature/ChildList.swift` is extracted into `ChildListModel`; keep the view focused on rendering and user-event forwarding.
- `ChildDetailView` logic in `Modules/AppFeature/ChildDetail.swift` is extracted into `ChildDetailModel`; keep grouped/filter/search/delete/share/reminder behavior in the model and keep presentation wiring in the view.
- `ItemFormView` logic in `Modules/AppFeature/ItemFormView.swift` is extracted into `ItemFormModel`; keep suggestion/emoji loading and item persistence in the model.
- In `@Observable` models that use SQLiteData, annotate `@FetchAll`/`@FetchOne`/`@Fetch` and `@Dependency` properties with `@ObservationIgnored`.
- Keep model injection explicit in views (`init(model: ...)`) plus convenience initializers (`init(child:)`, `init(item:)`) to support targeted unit tests and call-site ergonomics.
- Keep view-only environment concerns (e.g. `dismiss`) in the view; model methods should handle domain behavior and persistence.
- Trigger async model work from the view (`.task { await model... }`) rather than creating hidden task orchestration in the view body.
- For model tests, use `@Suite` traits with deterministic dependencies (`.dependency(\.context, .test)`, `.dependency(\.date.now, ...)`, `.dependency(\.uuid, .incrementing)`) and bootstrap via `.dependencies { try $0.bootstrapDatabase(seedData: false) }`.
- Mirror behavior tests at the model level (`ChildListModelTests`, `ChildDetailModelTests`, `ItemFormModelTests`) so refactors preserve UI behavior without needing UI tests.
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
- In this repo, see `Modules/AppFeature/Schema.swift` for migrations + sync setup and `Modules/AppFeature/ChildList.swift` / `Modules/AppFeature/ChildDetail.swift` / `Modules/AppFeature/ItemFormView.swift` for fetch/write usage.
