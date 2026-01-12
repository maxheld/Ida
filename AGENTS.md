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

<skills_system priority="1">

## Available Skills

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: Bash("openskills read <skill-name>")
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>app-store-changelog</name>
<description>Create user-facing App Store release notes by collecting and summarizing all user-impacting changes since the last git tag (or a specified ref). Use when asked to generate a comprehensive release changelog, App Store "What's New" text, or release notes based on git history or tags.</description>
<location>project</location>
</skill>

<skill>
<name>gh-issue-fix-flow</name>
<description>End-to-end GitHub issue fix workflow using gh, local code changes, builds/tests, and git push. Use when asked to take an issue number, inspect the issue via gh, implement a fix, run XcodeBuildMCP builds/tests, commit with a closing message, and push.</description>
<location>project</location>
</skill>

<skill>
<name>ios-debugger-agent</name>
<description>Use XcodeBuildMCP to build, run, launch, and debug the current iOS project on a booted simulator. Trigger when asked to run an iOS app, interact with the simulator UI, inspect on-screen state, capture logs/console output, or diagnose runtime behavior using XcodeBuildMCP tools.</description>
<location>project</location>
</skill>

<skill>
<name>macos-spm-app-packaging</name>
<description>Scaffold, build, and package SwiftPM-based macOS apps without an Xcode project. Use when you need a from-scratch macOS app layout, SwiftPM targets/resources, a custom .app bundle assembly script, or signing/notarization/appcast steps outside Xcode.</description>
<location>project</location>
</skill>

<skill>
<name>swift-concurrency</name>
<description>'Expert guidance on Swift Concurrency best practices, patterns, and implementation. Use when developers mention: (1) Swift Concurrency, async/await, actors, or tasks, (2) "use Swift Concurrency" or "modern concurrency patterns", (3) migrating to Swift 6, (4) data races or thread safety issues, (5) refactoring closures to async/await, (6) @MainActor, Sendable, or actor isolation, (7) concurrent code architecture or performance optimization, (8) concurrency-related linter warnings (SwiftLint or similar; e.g. async_without_await, Sendable/actor isolation/MainActor lint).'</description>
<location>project</location>
</skill>

<skill>
<name>swift-concurrency-expert</name>
<description>Swift Concurrency review and remediation for Swift 6.2+. Use when asked to review Swift Concurrency usage, improve concurrency compliance, or fix Swift concurrency compiler errors in a feature or file.</description>
<location>project</location>
</skill>

<skill>
<name>swiftui-liquid-glass</name>
<description>Implement, review, or improve SwiftUI features using the iOS 26+ Liquid Glass API. Use when asked to adopt Liquid Glass in new SwiftUI UI, refactor an existing feature to Liquid Glass, or review Liquid Glass usage for correctness, performance, and design alignment.</description>
<location>project</location>
</skill>

<skill>
<name>swiftui-performance-audit</name>
<description>Audit and improve SwiftUI runtime performance from code review and architecture. Use for requests to diagnose slow rendering, janky scrolling, high CPU/memory usage, excessive view updates, or layout thrash in SwiftUI apps, and to provide guidance for user-run Instruments profiling when code review alone is insufficient.</description>
<location>project</location>
</skill>

<skill>
<name>swiftui-ui-patterns</name>
<description>Best practices and example-driven guidance for building SwiftUI views and components. Use when creating or refactoring SwiftUI UI, designing tab architecture with TabView, composing screens, or needing component-specific patterns and examples.</description>
<location>project</location>
</skill>

<skill>
<name>swiftui-view-refactor</name>
<description>Refactor and review SwiftUI view files for consistent structure, dependency injection, and Observation usage. Use when asked to clean up a SwiftUI view’s layout/ordering, handle view models safely (non-optional when possible), or standardize how dependencies and @Observable state are initialized and passed.</description>
<location>project</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->

</skills_system>
