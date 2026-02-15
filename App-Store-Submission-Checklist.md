# Indie App Store Submission Checklist (Ida)

_Last updated: February 15, 2026_

Not legal advice. This is a practical pre-submission checklist tailored to this codebase.

## Current Status (Tailored to Ida)

1. `[Done]` Privacy manifest in app bundle
- Present at `/Users/maximilianheld/Developer/Ida/Ida/PrivacyInfo.xcprivacy`.
- Includes Required Reason APIs for:
- `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1`
- `NSPrivacyAccessedAPICategoryUserDefaults` with reason `C56D.1`

2. `[Done]` Basic Info.plist compliance
- `CFBundleDisplayName` exists in `/Users/maximilianheld/Developer/Ida/Ida/Info.plist`.
- `ITSAppUsesNonExemptEncryption = false` is set.

3. `[Action]` Privacy policy (required even for free apps)
- Add a public Privacy Policy URL in App Store Connect.
- Add an in-app privacy policy link (easy to find in Settings/About/Help).

4. `[Action]` App Privacy answers in App Store Connect
- Do not assume "Data Not Collected" by default.
- The app uses CloudKit and stores child names/entries (`/Users/maximilianheld/Developer/Ida/Modules/AppFeature/Schema.swift`), so disclosure must be accurate per Apple definitions.
- A mismatch between actual behavior and App Privacy answers is a high rejection/compliance risk.

5. `[Action]` DSA trader status declaration
- Complete trader-status declaration in App Store Connect.

6. `[Action]` Support/contact presence
- Ensure App Store Support URL is valid.
- Ensure users can contact you from the app or support page.

7. `[Done/Action]` Feature-triggered obligations (currently looks clean)
- Current code scan did not show obvious IAP, social login, account system, or ad SDK use in app source.
- If later added:
- Account creation -> must support in-app account deletion.
- In-app purchases -> include restore purchases flow.
- Ads/tracking -> include ATT flow and update privacy disclosures.

8. `[Action]` IP/license hygiene
- Confirm ownership or license for icons, graphics, fonts, copy, and other assets.
- Keep proof of licenses/rights.

9. `[Action]` Claims and metadata risk control
- Avoid unsupported medical/diagnostic or regulated claims.
- Keep App Store metadata and screenshots accurate and non-misleading.

10. `[Done]` Preflight process
- Continue running Greenlight before each submission.
- For this repo, root scans can include `.build` false positives; app-target scans are the useful signal.

## Biggest Legal Risks for a Free "No Data" App

1. Misstated privacy policy or incorrect App Privacy answers.
2. IP infringement (assets, branding, content rights).
3. Territory-specific compliance gaps (including EU trader status handling).

## Primary Sources

- App Review Guidelines: [https://developer.apple.com/app-store/review/guidelines/](https://developer.apple.com/app-store/review/guidelines/)
- App Privacy Details: [https://developer.apple.com/app-store/app-privacy-details/](https://developer.apple.com/app-store/app-privacy-details/)
- Third-party SDK requirements: [https://developer.apple.com/support/third-party-SDK-requirements/](https://developer.apple.com/support/third-party-SDK-requirements/)
- Approved reasons for APIs: [https://developer.apple.com/news/upcoming-requirements/?id=05012024a](https://developer.apple.com/news/upcoming-requirements/?id=05012024a)
- EU DSA trader requirements: [https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- Export compliance overview: [https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)

## Quick Reuse Notes

- Re-run this checklist before each release.
- Re-validate privacy disclosures whenever dependencies or app features change.
- If you add auth, payments, ads, health, finance, or kids-directed features, do a dedicated compliance pass.
