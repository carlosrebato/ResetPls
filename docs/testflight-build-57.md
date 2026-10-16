# TestFlight 1.0 (57) — 2026-10-15

## Changes since build 56

- The iPhone weekly-quota chart now uses the previously empty upper lane,
  matching the approved Mac layout without increasing the enclosing panel.
- Remove the redundant 100% scale label; the upper dotted guide remains 100%.
- Inspection labels use available space around the series. Touch/release
  behavior and existing current-day endpoint labels remain unchanged.
- Start the iOS 1.0 version train for the prepared App Store listing. Mac
  remains 0.1.8 (56); its update feed is not changed by this upload.

## Verification

- 188 shared/Mac/provider tests passed with the chart change (22 + 166).
- iOS Release build and signed archive succeeded. App and widget versions
  verified as 1.0 (57), with UIDeviceFamily containing only 1 (iPhone).
- No simulator was booted. Physical-iPhone interaction testing remains with
  the owner through TestFlight.
- Upload and Apple processing are verified separately before handoff; this
  build has not been submitted to App Store review.
