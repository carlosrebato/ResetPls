# TestFlight 1.0 (69) — 2026-11-03

Source: current ResetPls working tree, including pre-existing changes. iPhone app and widget archived with CURRENT_PROJECT_VERSION=69; Mac version unchanged.

- Shared, persistent iPhone demo selection; dashboard and installed widgets use matching synthetic samples, labeled DEMO.
- Demo selection lives in a separate app-group flag. Real caches, credentials and history are not overwritten. Exiting demo reloads widget timelines.
- Widget and background refresh skip provider requests during demo.
- Mac download callout: whole card links to https://resetpls.app; Download/Descargar uses 12 pt semibold, matching the language selector.

Validation: three demo tests passed (restore real data, empty-account exit, in-flight authentication guard), simulator and signed Release archive succeeded. App and extension identities/version checked; deep strict codesign verification passed. English and Spanish Settings visually checked in iPhone 18 Pro simulator; CTA fits without truncation.

Archive: /tmp/resetpls-ios-69.xcarchive
Upload log: /tmp/resetpls-ios-69-upload.log
Visuals: /tmp/resetpls69-settings.png and /tmp/resetpls69-settings-es.png

Upload succeeded; Apple reports VALID. Superseded by build 70 (capsule styling).
