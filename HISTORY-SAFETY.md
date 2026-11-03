# History preservation

Release objective: upgrades must preserve users' observed weekly percentages and must never replace unreadable history with a fresh document.

All three history writers validate the input before writing. Invalid JSON, unknown fields, unsupported schema versions, duplicate dates and read errors stop persistence. Existing unversioned files remain supported. Writes emit schemaVersion 1. Adding future fields requires updating the format validation and preservation tests together.

Before replacing valid nonempty history, the app saves exact original bytes alongside it in `usage-history-backups/`:
- `before-protection-v1.json`: first protected input, never rotated or overwritten.
- `daily-YYYY-MM-DD.json`: first protected input that UTC day; seven daily copies retained.

If a required backup fails, the primary file is not changed. Backups remain local. If the primary disappears while backups exist, writes stop rather than starting over. Recovery is deliberately manual: quit ResetPls, preserve the current primary, inspect and validate a backup, then copy it to `usage-history.json`. Do not relabel old peak/session percentages as weekly observations.

The existing 60-day retention policy is unchanged. These safeguards do not modify already-distributed binaries: do not install an older writer over newer user data. App rollback requires compatible data handling; a binary backup alone is insufficient. Baseline and daily copies provide recovery evidence, not an absolute guarantee against disk loss or arbitrary external writers.

`UsageHistoryProtectionTests` covers legacy upgrade, all history writers, weekly observations and timestamps, malformed/future formats, failed backups, bounded retention, missing primary and new installs. Existing CI and release-readiness run these tests through `swift test`. A release must also validate the actual artifact and its UI using the current ResetPls repository. Never build ResetPls from the historical NSPanel copy.
