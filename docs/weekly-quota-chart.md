# Weekly quota chart

Mac and iOS default to a fixed 0–100% scale showing the most recent live weekly
quota balance observed on each local calendar day. Claude's session percentage
is not used. A later measurement may be lower, including zero after a scheduled
or courtesy reset. Stale, missing and cached responses never fabricate a zero.

Mac offers a persistent metric picker (`usageTrendMetric.v1`) with weekly quota
and daily local tokens. iOS and widgets always show weekly quota. The tokens
option retains the existing daily totals, dynamic scale and empty-day rendering.

Legacy daily primary-window peaks and all token/activity history are retained.
They cannot be reinterpreted as weekly closing balances. New optional weekly
fields begin collecting on upgrade; missing older dates remain unmeasured.
Each device records its own observations; this does not add cloud synchronization.

## Verification plan

- Core regression tests: session/weekly separation, same-day and midweek resets,
  out-of-order and cached observations, missing dates, fixed scale and default.
- Persistence tests: decode old history, retain tokens and activity, merge later
  local token scans without changing weekly balances.
- Platform builds: signed Mac app and widgets; iOS simulator app and widgets.
- Manual UI check: Mac picker changes metric and survives reopening; iOS has no
  picker. Both show weekly percent endpoints and connect observed reset drops.
