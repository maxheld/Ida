# Pre-Submit Gate (Ida)

_Last updated: February 15, 2026_

Run this gate before every App Store upload.

## 1) Automated Gate

- Run:
  - `/Users/maximilianheld/Developer/Ida/ci_scripts/pre_submit_gate.sh`
- This script:
  - Runs `greenlight preflight Ida --format json`
  - Fails on any CRITICAL finding
  - Prints WARN/INFO counts for manual follow-up

## 2) Build Gate

- Run a release build:
  - `xcodebuild -scheme "Ida - Release" -configuration Release build`

## 3) Human Compliance Gate

- Complete `/Users/maximilianheld/Developer/Ida/App-Store-Submission-Checklist.md`.
- Confirm App Privacy answers match:
  - `/Users/maximilianheld/Developer/Ida/Data-Inventory-and-App-Privacy-Mapping.md`
- Verify legal URLs in App Store Connect are live:
  - Privacy Policy URL
  - Support URL

## Pass/Fail Rule

- PASS: release build succeeds and pre-submit script reports `critical=0`.
- HOLD: any critical finding, build failure, or unchecked required legal/compliance item.
