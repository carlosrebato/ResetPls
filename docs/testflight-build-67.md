# TestFlight 1.0 (67) — 2026-11-03

Source: the ResetPls repository, current working tree, including existing uncommitted changes.

## Change
- Applies Carlos's approved option A icon: stronger green halo and circular ripple on the near-black background with reflective rim.
- Updates the matching in-app brand image.
- iOS application and widget build numbers are 67. Placeclock is untouched.
- No history code or schema changes in this task.

## Validation
- Release archive succeeded; deep/strict signature verification passed.
- App crbg.resetpls and widget crbg.resetpls.widgets both verified as 1.0 (67).
- Input app icon is opaque RGB, 1024×1024. Inspected the 120×120 compiled app icon after decoding Apple's PNG optimization.
- Existing six UsageHistoryProtectionTests passed during the preceding Mac icon installation in this same task.
- Physical iPhone appearance remains to be checked through TestFlight.

## Distribution
Upload succeeded through Xcode using the existing App Store Connect API key. Apple package processing is pending; build 67 is not yet returned by the builds API. The existing Internos group has automatic access to all builds. No App Store release was submitted.

## Artifacts
- Archive: /private/tmp/resetpls-ios-67.xcarchive
- Archive log: /private/tmp/resetpls-ios-67-archive.log
- Upload log: /private/tmp/resetpls-ios-67-upload.log
- Compiled icon preview: /private/tmp/resetpls-ios-67-icon-preview.png
