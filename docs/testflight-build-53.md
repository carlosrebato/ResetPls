# TestFlight candidate 0.1.7 (53) — 2026-10-08

## Included

- The same weekly quota measure on iOS and Mac: latest valid weekly percentage
  observed on each day, fixed 0–100% scale, drops on provider resets, no invented
  values for days without observations. Mac retains its optional tokens graph.
- Existing Home Screen and Lock Screen widgets and background refresh fixes.
- Demo accessible from the welcome screen and Settings → Preferences.
  The dashboard labels sample data explicitly. Demo refresh/sign-in/sign-out
  cannot overwrite real account caches/history or remove credentials.
  Exiting demo restores the saved readings and permits a normal refresh.
- App and iOS widget privacy manifests: UserDefaults CA92.1 / 1C8F.1.
- Updated App Review notes describing the actual product and review access.

## Verification

- Shared/macOS tests: 22 provider-service tests and 156 core/UI/macOS tests pass.
- iOS final run: 16 tests pass, including demo cache preservation, exit,
  sign-in exclusion and actual embedded manifests. One intermediate attempt
  lost its test-runner channel; the final retry completed without failures.
- Release archive: `/private/tmp/ResetPls-iOS-53.xcarchive`.
- App and embedded widget signature verification passed; both embed the manifest.
- Upload completed at 14:02 CEST: `Upload succeeded` / `EXPORT SUCCEEDED`.
  Apple reported `Uploaded package is processing`. Tester availability has not
  been confirmed in App Store Connect. Processing, tester availability and
  physical-device checks are separate states; upload is not App Store approval.

## Remaining public-submission gates

- Physical iPhone: returning to app, provider sign-in/refresh, reset, widget
  refresh and selection, demo on/off with existing accounts.
- App Store Connect: latest screenshots in English/Spanish and iPad if supported,
  description/subtitle, app privacy questionnaire, age rating, export compliance,
  support/privacy URLs, review contact and current review instructions.
- Provider authorization is not verified. Anthropic's current developer guidance
  prefers API-key authentication for third-party products, not subscription OAuth:
  https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account
  OpenAI's terms restrict programmatic data extraction; the applicability to this
  quota-only integration needs explicit clarification, not an assumed exception:
  https://openai.com/policies/terms-of-use/
  Apple guideline 5.2.2 may request proof of permission. No provider permission
  or App Store public-review submission is asserted by this document.
