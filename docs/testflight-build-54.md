# TestFlight candidate 0.1.7 (54) — 2026-10-08

## Changes from build 53

- Remove the TOKENS metric and unavailable-token explanation from the iOS
  dashboard, for both Claude and Codex and in English and Spanish. Local token
  metrics and the optional tokens chart remain available on Mac.
- Shared privacy link now points to https://resetpls.app/privacy/ with the
  Spanish policy linked at https://resetpls.app/es/privacy/.
- Owner explicitly accepts the provider-integration publication risk. It is
  recorded in `APP_REVIEW.md`, not a prerequisite to proceeding with submission.
  Do not claim verified provider permission or hide the integrations.

## Verification

- 22 provider-service tests and 158 shared/macOS tests pass.
- 17 iOS tests pass on the dedicated ResetPls simulator.
- Actual image renders are text-recognized in English and Spanish: TOKENS is
  absent on iOS and retained on Mac. Provider names remain readable in the test.
- Release archive succeeded at `/private/tmp/ResetPls-iOS-54.xcarchive`.
- Upload completed at 15:31 CEST: `Upload succeeded` / `EXPORT SUCCEEDED`.
  Apple reported `Uploaded package is processing`. Tester availability is not
  yet confirmed. Physical iPhone checks and completing the App Store Connect
  listing remain outstanding.
