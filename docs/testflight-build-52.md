# TestFlight 0.1.7 (52): background refresh and truthful widget status

Addresses GitHub #3 and #4. Build 51 remains unchanged on App Store Connect.

## Implementation

- Both iOS timeline providers fetch through SharedUsageRefresh before loading
  saved snapshots. Reloading a timeline is no longer just re-reading old data.
- The iOS foreground store and BGAppRefresh handler use the same refresh layer.
  Background refresh is registered as crbg.resetpls.refresh and requested after
  entering background and after each background invocation. The plist declares
  the permitted identifier and fetch mode as arrays.
- An app-group advisory file lock covers provider requests, OAuth rotation and
  cache/status/history writes across refresh callers, including separate widget
  processes. Contending callers return saved data rather than duplicate requests.
  The OS releases the lock if a process exits; cancellation also releases it.
- Normal callers reuse attempts for five minutes; provider rate-limit deadlines
  are persisted and respected even by forced foreground refreshes.
- The extension uses the app's existing default keychain group. Tokens remain
  device-only in the Keychain, never in app-group files or diagnostics. Existing
  app credentials do not need a group migration.
- Evidence records contain timestamps, execution context, retry deadline and an
  allowlisted error category. Diagnostics also include background scheduling
  acceptance and a numeric scheduler error, without raw errors or credentials.
- Shared freshness assessment distinguishes current, saved and failed. A saved
  or aged reading uses neutral text; only a failed attempt after the last valid
  observation shows UPDATE FAILED / FALLO AL ACTUALIZAR. Reauthentication keeps
  its separate action. The shared widget status logic applies on Mac too; Mac
  refresh orchestration is unchanged.

## Test plan and coverage

Critical coverage: new observations persist from a non-foreground caller;
cadence deduplicates successive callers; independent coordinators contend for
the same file lock; failures preserve last values; success clears failure;
rate-limit backoff survives restart; cancellation is not a provider failure and
releases the lease; old data without failed evidence is not an error.

These are deterministic integration/unit tests with fake adapters; no provider
credentials are used. Existing iOS tests cover pace persistence, connection
state, cancellation of sign-in and diagnostic privacy. Mac compilation checks
the shared widget status path without enabling direct refresh on Mac widgets.

Physical-device gap: iOS decides when to run widget timelines and background
tasks. Simulator or automated tests cannot prove real scheduling latency,
low-power behavior, or every existing account's token renewal. Do not promise a
15-minute guarantee. After installing 52, open the app once, then observe the
widget with the app in background and export its diagnostic if readings stall.

Unrelated limitations from 51 remain: actual missing reset needs the device
diagnostic, direct iOS APIs do not supply local token history, and explicit widget
service-selection rendering still needs the user's real-device test.
