# Pace assessment contract

Mac, iOS, widgets, status copy and provider signals use the same core assessments.
The approved English and Spanish strings remain in `AppLanguage`.

## Session

- A fresh provider reading with known duration, usage and reset is sufficient for
  an initial estimate. No count of local observations is required.
- Only exactly zero usage produces the no-usage state. Display rounding must not
  change the underlying state.
- Rates and projected deadlines are computed at `observedAt`. UI time only counts
  down the deadline and determines whether the evidence has become stale.
- The initial rate is `usedPercent / max(elapsed, warmup)`. Warmup is 15 minutes
  or 10% of a shorter window. This damps tiny elapsed times continuously; there
  are no 20% or 70% usage gates.
- Three valid observations spanning ten minutes can describe a recent trend.
  A single delayed jump cannot establish that trend, but does not disable the
  session average.
- The recent trend's weight rises continuously from zero at ten minutes to one
  at an hour. A short pause cannot immediately erase the session's consumption.
  A sustained pause can change the estimate. When usage resumes after a verified
  pause, start the trend segment at the end of that pause.
- Alert when the projected consumption at reset exceeds 105%. The five-point
  tolerance accounts for coarse readings near the boundary; the ETA itself
  projects the 100% limit. A prediction past its deadline remains an alert until
  new evidence or staleness replaces it, with a minimum displayed ETA of ~1m.
- Cache, stale data, invalid timing, missing reset and insufficient evidence
  have explicit diagnostic reasons. Older caches without duration may use a
  sufficiently established recent trend. Unsupported durations over 24 hours
  never generate a session forecast.
- Small reset timestamp drift (up to one minute) retains observations. A real
  reset or decreasing usage starts a new series.
- `primaryQuotaID` identifies the quota. Equal values must not make a session
  become weekly. The compatibility estimate delegates to this primary quota.

`SessionPaceAssessment` carries the status, basis, reason, observation time, rate,
projection and deadline. Diagnostics export only basis and reason, not percentages
or account data.

## Weekly

Use verified seven-day quotas and the provider observation time. During day one,
use at least one day's share of the week; after that use the elapsed window.
Thresholds remain <80%, 80–105%, >105–125% and >125% projected consumption. High
risk stays amber during the first 48 hours, then becomes red. This classification
does not depend on the number of local observations, so identical current weekly
readings and reset times produce the same result on Mac and iOS.

## Collection

Mac retains its five-minute ordinary polling interval. iOS now collects every
five minutes while the dashboard is active; its 30-second UI timer does not itself
count as evidence. Initial estimation works even without this polling history.
Cached evidence is preserved across suspension, failed refreshes and restart;
it cannot make a live pace claim until a valid live reading arrives.

## Reproduced audit scenarios

| Input | Result with the shared assessment |
| --- | --- |
| 87% after 64 minutes; one reading | Session limit in ~10m |
| 87% unchanged for another ten minutes, verified readings | Session limit in ~12m; no instant recovery |
| 60% after four hours; one reading | Should make it to the session reset |
| 19.9% and 20% after 15 minutes | Both session limit in ~1h |
| Provider reports 0.4% after ten minutes | Usage exists; should make it to the reset |
| Weekly 40% after two days and 30 minutes, rich or sparse history | Both high weekly risk |
| 87% unchanged for a full hour, verified readings | Should make it to the reset; the quota dot still reflects 87% used |

The meaningful regression checks include the reset instant, sparse sampling,
brief/sustained pauses, resumption, delayed provider jumps, cache round trips,
fractional usage, drift, rollover, unavailable data and UI-clock invariance.
