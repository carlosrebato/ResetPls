# TestFlight 1.0 (65) — 2026-11-03

Source: the ResetPls repository, current working tree. No historical NSPanel source used.

## Changes
- iPhone Settings includes the localized free Mac download callout below Language.
- Includes current history protection: local baseline/daily backups, schema-version checks, and refusal to overwrite unreadable or unsupported history.
- Explicitly excludes two local duplicate Swift files from SwiftPM compilation without deleting them.
- iPhone application and widget build number: 65; marketing version: 1.0. Mac versions unchanged.

## Validation and distribution
- 192 shared/provider/macOS tests passed.
- 20 iOS tests passed on iPhone 18 Pro / iOS 27.0 simulator.
- Settings visually inspected in simulator: Mac callout visible and legible.
- Signed Release archive and deep/strict code-signature verification passed.
- App crbg.resetpls and widget crbg.resetpls.widgets both verified as 1.0 (65), iPhone-only, with privacy manifests.
- Xcode 27.1 archive uploaded using existing App Store Connect API key, no browser session required.
- Apple processingState VALID; internalBuildState READY_FOR_BETA_TESTING.
- Build ID: bd0ab5a8-ff90-46a3-ab48-a448258e7b83.
- Membership verified in existing Internos group (automatic access to all builds).
- What to Test saved in Spanish and English.
- Physical-iPhone live sign-in, quota history and WidgetKit refresh validation remains with Carlos through TestFlight.

## Reproducibility
Archive: /tmp/resetpls-ios-65.xcarchive
Archive log: /tmp/resetpls-ios-65-archive.log
Upload log: /tmp/resetpls-ios-65-upload.log
Shared tests: /tmp/resetpls-ios-release-tests.log
iOS tests: /tmp/resetpls-ios-65-tests.log

The archive was produced from the current working tree, including pre-existing uncommitted changes. Do not attribute it solely to HEAD.
