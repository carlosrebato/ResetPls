# ResetPls — iOS App Review notes

Release candidate: 0.1.7 (54). TestFlight validation is not App Store approval.

## Reviewer instructions (English)

ResetPls is an independent usage viewer for Claude Code and Codex. It is not
affiliated with Anthropic or OpenAI, and does not provide chat or inference.

To explore without an account, tap **Explore demo** on the welcome screen.
If the welcome screen was dismissed, open **Settings → Preferences → Demo mode**.
The dashboard displays explicitly marked, synthetic sample data, including
session/weekly percentages, reset countdowns, pace estimates and the seven-day
weekly quota chart. Refresh in demo mode updates the samples without querying a
provider. Turn demo mode off in Settings to restore real account readings.
Demo samples are not written into real account caches or history.

For live use, connect a provider from the welcome screen or Settings → Accounts
using your own existing provider account. Sign-in uses the provider's browser
authentication with PKCE. Tokens are kept in this device's Keychain; there is no
ResetPls account, credential relay, telemetry service or cross-device sync.
Sign out separately in Settings → Accounts.

Home Screen widgets: small (choose one service via Edit Widget), medium (both
services), large (both services and chart). Lock Screen widgets: inline,
circular (one service), rectangular (both services). The system widget gallery
uses fresh synthetic previews. Installed widgets use real account data and do
not inherit the app's in-memory demo. iOS decides background refresh timing;
an update at a fixed interval is not guaranteed. Saved readings and failed
updates are distinguished from fresh readings.

The graph records the latest observed **weekly quota used (%)** for each day,
not tokens or the day's peak session usage. Provider resets may cause a drop.
Days without observations remain unknown. iOS does not read desktop transcripts
and therefore does not display desktop token totals.

Pace text is an estimate based on recorded quota/time observations, not a
provider guarantee. ResetPls has no StoreKit purchases, chat, or push alerts.

The app queries read-only provider usage endpoints through public clients.
These are not documented third-party integration APIs. Do not represent them
as official ResetPls integrations or claim provider authorization we do not have.

Support: https://github.com/carlosrebato/ResetPls#readme
Privacy: https://resetpls.app/privacy/ (English), https://resetpls.app/es/privacy/ (Spanish)

## Submission gates

- Verify this build on a physical iPhone (sign-in, resume, refresh, reset,
  widgets, demo entry/exit with and without existing accounts).
- Confirm App Store Connect screenshots, app privacy answers, age rating,
  export compliance, support/privacy links and reviewer contact details.
- App and iOS widget embed `Configurations/PrivacyInfo.xcprivacy`:
  UserDefaults reasons CA92.1 (app-only settings) and 1C8F.1 (App Group settings).
  No tracking or developer-side data collection. Re-audit when adding APIs/SDKs.
- No App Store submission is recorded by this document. Do not hide an
  integration or misstate capabilities to bypass review.

## Accepted publication risk — owner decision, 2026-10-08

Proceed with publication without making provider authorization a prerequisite.
The owner has explicitly accepted this integration risk. Authorization remains
unverified; other published trackers and TestFlight acceptance are not proof of
permission, and Apple may request supporting evidence under guideline 5.2.2.
Record that factual limitation without repeatedly reopening the same decision.
