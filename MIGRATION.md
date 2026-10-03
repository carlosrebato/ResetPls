# ResetPls repository migration

The current public release repository is `carlosrebato/ai-usage-mac`. Existing
Mac installations read `https://raw.githubusercontent.com/carlosrebato/ai-usage-mac/main/appcast.xml`.
This private repository must not replace that feed or its signed release assets
until an end-to-end update has been tested from a currently installed build.

## Prepared here

- Public-repository history and its uncommitted work were preserved in ordered
  integration commits. The newer native app and tests were then merged from the
  NSPanel working copy, without overwriting public-only files blindly.
- The landing source lives in `landing/`. Device-frame binaries with third-party
  redistribution restrictions are not committed; the existing deployed site
  remains the live site until replacement assets or suitable rights are ready.

## Cutover gates

1. Finish the code review, macOS/iOS build checks, and secret scan.
2. Keep `ai-usage-mac` public and its current appcast available while this
   repository is private. A private GitHub raw URL or release download is not a
   public Sparkle update endpoint.
3. When a public ResetPls feed is ready, publish a higher-version, correctly
   signed bridge release through the **old** appcast. The bridge app keeps the
   same bundle ID, signing identity and Sparkle public key, but points future
   checks to the new public appcast.
4. Test updating an existing installation through the old feed and then test
   the next check against the new feed. Leave the old feed available for users
   who have not launched the app yet.
5. Only after the source, release, and landing have moved successfully, remove
   the duplicate native app and landing from NSPanel in a separate commit.

No step in this document authorizes replacing an installed app or publishing a
release before the update path is verified.
