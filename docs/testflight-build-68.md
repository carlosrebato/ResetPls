# TestFlight 1.0 (68) — 2026-11-03

Source: current working tree of `the ResetPls repository`, including pre-existing edits. No Placeclock changes.

- Removes baked-in white/gray highlights and rim from the ResetPls artwork.
- Both apps now use `App/ResetPlsIcon.icon` with solid black fill and glass/specular/translucency disabled.
- Matching in-app brand images updated; the Mac Settings icon no longer has an extra white stroke.
- History code/schema unchanged by this correction.

Validation: Mac and iOS Release builds succeeded and signatures verified; Mac Finder appearance verified after local installation; iOS icon verified in simulator App Library. Physical iPhone appearance remains for Carlos to review via TestFlight.

Mac: 0.1.9 (68), installed and opened, app/container/group backup in `ResetPls-backups` with suffix `before-black-icon-build68`; schema 1 and 59 history days retained.

iOS: 1.0 (68), archive `/private/tmp/resetpls-ios-68.xcarchive`; upload succeeded, Apple processing pending. Log: `/private/tmp/resetpls-ios-68-upload.log`.
