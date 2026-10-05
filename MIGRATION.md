# ResetPls repository migration

## Manual cutover — 2026-10-05

The owner made `carlosrebato/ai-usage-mac` private and chose a one-time manual
install for the two external clients, Álvaro and Viti. The maintainer's Mac is
migrated locally. The retired private feed cannot serve automatic updates.

ResetPls 0.1.7 (48) and later read
`https://raw.githubusercontent.com/carlosrebato/ResetPls/main/appcast.xml`.
Signed downloads and website links now use the public ResetPls repository.

Quit the running app, unzip the notarized download and replace **ResetPls.app**
in Applications. If the old app is still named **AI Usage.app**, remove only
that old app bundle after quitting it; do not run both apps. Do not clear
preferences, App Group data or Keychain entries.

Bundle ID `com.carlosrebato.aiusage`, team `467CC6L4BF`, App Group and Sparkle
public key stay unchanged. Preferences, connections and stable/beta selections
are preserved. Both channels share the feed: stable items are untagged; future
beta items must carry Sparkle's `beta` channel tag.

## Prepared here

- Public-repository history and its uncommitted work were preserved in ordered
  integration commits. The newer native app and tests were then merged from the
  NSPanel working copy, without overwriting public-only files blindly.
- The landing source lives in `landing/`. Device-frame binaries with third-party
  redistribution restrictions are not committed; the existing deployed site
  remains the live site until replacement assets or suitable rights are ready.
- Source publication and updater migration are separate operations. Making
  ResetPls public does not redirect any installed client's Sparkle feed.

## Release checks

1. Tests and universal Mac archive pass; app and widget use Developer ID signing.
2. Final ZIP is Apple-notarized and passes codesign, stapler and Gatekeeper after
   extraction. Its EdDSA signature verifies against the app's Sparkle key.
3. New public feed and release ZIP are accessible without GitHub authentication.
4. Web `/`, `/en/` and `/es/` all download the same signed release.
5. Installed maintainer app keeps existing settings and reads the new feed.

There is no automatic redirect from the old private feed. External clients must
install the new ZIP once before automatic updates resume. Removing duplicate
native and landing sources from NSPanel is a separate cleanup task.
