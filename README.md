# Ida

Ida is an iOS app for tracking baby and child activities with a fast local database and optional CloudKit sync.

## What It Does

- Manage children and activity entries
- Search and filter logged items
- Create and manage reminders
- Sync data through CloudKit when configured
- Localize app strings via string catalogs

## Tech Stack

- Swift 6
- SwiftUI
- SQLiteData (Point-Free)
- CloudKit sync engine integration

## Project Layout

- `Ida/`: App target shell, entitlements, app-level assets and localizations
- `Modules/AppFeature/`: Main feature code (views, models, schema, reminders, resources)
- `Modules/AppFeatureTests/`: Unit tests for `AppFeature`
- `Modules/Package.swift`: Local Swift package definition
- `ci_scripts/`: CI helper scripts

## Requirements

- macOS with a recent Xcode version that supports the iOS 26 SDK
- iOS Simulator (project defaults target iPhone 17 in local workflows)

## Getting Started

1. Clone the repository.
2. Open `Ida.xcworkspace` in Xcode.
3. Select the `Ida` scheme.
4. Choose an iOS simulator and run.

## Build

From the repository root:

```bash
xcodebuild -scheme Ida -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Release build:

```bash
xcodebuild -scheme "Ida - Release" -configuration Release build
```

## Testing

- Unit tests are in `Modules/AppFeatureTests/`.
- Use the `AppFeature` scheme and `Modules/AppFeature.xctestplan` in Xcode.
- Note: the app scheme (`Ida`) is not configured with a test action.

## CloudKit Notes

CloudKit capabilities and container settings are defined in:

- `Ida/Ida.entitlements`
- `Modules/AppFeature/Schema.swift`

If you fork this project, update container and signing settings to your own team/account.

## License

Source-available, all rights reserved. See `LICENSE.md`.
