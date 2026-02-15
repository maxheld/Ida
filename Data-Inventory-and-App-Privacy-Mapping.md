# Data Inventory and App Privacy Mapping (Ida)

_Last updated: February 15, 2026_

Practical working doc for App Store Connect "App Privacy" answers.

## Scope and Evidence

- Database schema: `/Users/maximilianheld/Developer/Ida/Modules/AppFeature/Schema.swift`
- Notification behavior: `/Users/maximilianheld/Developer/Ida/Modules/AppFeature/Reminders/ReminderClient.swift`
- Notification action write-back: `/Users/maximilianheld/Developer/Ida/Modules/AppFeature/AppDelegate.swift`
- CloudKit share acceptance: `/Users/maximilianheld/Developer/Ida/Modules/AppFeature/SceneDelegate.swift`
- Entitlements/capabilities: `/Users/maximilianheld/Developer/Ida/Ida/Ida.entitlements`
- Privacy manifest: `/Users/maximilianheld/Developer/Ida/Ida/PrivacyInfo.xcprivacy`

## Data Inventory

| Data element | Source | Storage/transfer path | Notes |
|---|---|---|---|
| Child name | User input (`Child.name`) | SQLite local DB, synced through CloudKit `SyncEngine` | User-generated content |
| Item description | User input (`Item.description`) | SQLite local DB, synced through CloudKit `SyncEngine` | User-generated content |
| Item date/time | App/user action (`Item.date`) | SQLite local DB, synced through CloudKit `SyncEngine` | Timeline metadata |
| Reminder text/time/weekday | Reminder form + scheduler | Stored in pending local notification requests (`UNUserNotificationCenter`) | Used for on-device reminders |
| Reminder payload child ID/description | Notification `userInfo` | On-device notification payload; used when handling add action | Used to create `Item` from notification action |
| CloudKit share metadata | Share flow in child detail | CloudKit share APIs (`CKShare`) | Only when user triggers sharing |

## Recommended App Privacy Mapping (Conservative)

Use these as default answers, then confirm with legal/compliance owner before submission:

- `Data Used to Track You`: `No` (current manifest has `NSPrivacyTracking = false`).
- `Data Linked to You`: treat user-entered child/item content as linked for conservative disclosure.
- `Data Types to declare`:
  - `User Content > Other User Content` (child names, item descriptions)
  - `Usage purpose`: `App Functionality`
- `Data Not Linked to You`: reminder scheduling metadata can remain on-device, but re-check if implementation changes.
- `Third-party advertising/analytics SDK data collection`: none identified in app target/package setup.

## Privacy Manifest Mapping

Current `PrivacyInfo.xcprivacy` values:

- `NSPrivacyCollectedDataTypes`: empty array
- `NSPrivacyTracking`: false
- `NSPrivacyAccessedAPITypes`:
  - `NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1`
  - `NSPrivacyAccessedAPICategoryUserDefaults` reason `C56D.1`

## Change Triggers (Re-review Required)

Re-open this doc and re-answer App Privacy if any of the following is added:

- Analytics/ads/tracking SDKs
- Sign in providers or account systems
- Digital purchases/subscriptions
- New permissions (camera, microphone, photos, location, health)
