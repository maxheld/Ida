# App Store Connect Submission Checklist (Ida)

_Last updated: February 15, 2026_

Use this as a release blocker checklist for required fields and legal/compliance declarations.

## 1) Required App Store Connect Fields

- [ ] App name, subtitle, primary category, and content rights are complete and final.
- [ ] Support URL is live and reachable.
- [ ] Privacy Policy URL is live and reachable.
- [ ] Screenshots are current and represent actual app behavior.
- [ ] "What’s New" text matches shipped changes.
- [ ] Build selected for the version is the intended release build.

## 2) App Privacy + Data Disclosure

- [ ] App Privacy questionnaire is completed using `/Users/maximilianheld/Developer/Ida/Data-Inventory-and-App-Privacy-Mapping.md`.
- [ ] Tracking is set correctly (current app manifest shows `NSPrivacyTracking = false` in `/Users/maximilianheld/Developer/Ida/Ida/PrivacyInfo.xcprivacy`).
- [ ] Required Reason APIs remain accurate:
  - `NSPrivacyAccessedAPICategoryFileTimestamp` -> `C617.1`
  - `NSPrivacyAccessedAPICategoryUserDefaults` -> `C56D.1`
- [ ] If data behavior changed since last release, privacy answers were re-reviewed.

## 3) Legal + Regulatory Declarations

- [ ] Export compliance answer is correct (current app sets `ITSAppUsesNonExemptEncryption = false` in `/Users/maximilianheld/Developer/Ida/Ida/Info.plist`).
- [ ] EU DSA trader status is completed and current.
- [ ] Age rating questionnaire is complete and accurate.
- [ ] Any territory-specific legal text (if used) is final and reviewed.

## 4) Capability-Linked Compliance Checks

- [ ] iCloud/CloudKit capability declarations are consistent with app behavior (`/Users/maximilianheld/Developer/Ida/Ida/Ida.entitlements`).
- [ ] Push notification behavior is represented accurately in metadata (`aps-environment`, `remote-notification`).
- [ ] If account creation is introduced later, include in-app account deletion.
- [ ] If digital purchases are introduced later, include restore purchases flow.
- [ ] If ads/tracking SDKs are introduced later, add ATT flow and update privacy answers.

## 5) Final Submission Gate

- [ ] Run `/Users/maximilianheld/Developer/Ida/ci_scripts/pre_submit_gate.sh` and resolve any CRITICAL findings.
- [ ] Run a clean release build before upload:
  - `xcodebuild -scheme "Ida - Release" -configuration Release build`
