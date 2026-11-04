# TestFlight 1.0 (66) — 2026-11-03

Source: the ResetPls repository, current working tree, including pre-existing uncommitted changes.

## Changes
- iPhone medium widget uses Claude as its compact provider name, avoiding the truncated Claude C… label.
- Short localized pace estimates fit small, medium and large widgets; estimates retain session/week context and conditional language where applicable.
- iPhone widget streak displays — when today has no activity/token evidence, matching the dashboard. History and its schema are unchanged.
- iPhone app and widget build numbers are 66; Mac behavior and versions are unchanged.

## Validation
- 20 iOS tests passed on iPhone 18 Pro / iOS 27 simulator.
- Six SwiftUI renders inspected: small, medium, large in English and Spanish. Narrow sizes: 155×155, 329×155, 329×345 points. No observed provider/pace clipping; unavailable streak displays —.
- Temporary rendering harness used a copy of production widget views with explicit family injection; restored original test file afterward. These renders do not validate WidgetKit scheduling or system host behavior.
- Render artifacts: reviews/widget-fixes-20261103/.
- Release archive succeeded; deep/strict signature verification passed. App crbg.resetpls and widget crbg.resetpls.widgets both 1.0 (66).
- Physical-device widget refresh and final screenshot acceptance remain with Carlos.

## Distribution
Upload succeeded via local Xcode and existing App Store Connect API key. Apple processing pending. First upload stalled on an API request; retry completed successfully.

## Logs
- /tmp/resetpls-ios-66-tests.log
- /tmp/resetpls-ios-66-render.log
- /tmp/resetpls-ios-66-archive.log
- /tmp/resetpls-ios-66-upload.log
- /tmp/resetpls-ios-66-upload-retry.log
- Archive: /tmp/resetpls-ios-66.xcarchive
