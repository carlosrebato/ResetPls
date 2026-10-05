# Session pace transitions

The shared `AIUsageCore` assessment drives macOS, iOS and widgets. Weekly risk
is unchanged. Session pace remains a conditional estimate, not a promise about
future activity.

## Evidence and transitions

- Live zero use: `noUsage`. Cached, stale, missing or invalid evidence must not
  claim a live conclusion. An exhausted quota shows availability instead.
- Startup lasts up to 15 minutes (or 10% of shorter windows). The calculation
  still runs, but low initial consumption cannot produce reassuring copy.
- The central rate uses the actual elapsed time, with a one-minute floor at the
  reset instant. Verified recent trends retain their existing gradual blend.
- A half percentage-point reading guard is propagated through the average.
  Trend-rate tolerance is one percentage point divided by the sample span.
  This is a deliberate stability tolerance, not a statistical confidence bound.
- Warn when the lower projection is above 100%. During startup the lower
  projection must also exceed 100% using the startup denominator. This dampens
  the warning decision, not the warning ETA, and never establishes safety.
- After startup, show on-track only when the upper projection is below 100%.
  The previous blanket five-point safety tolerance is removed.
- In the ambiguous band, retain the last conclusion for the same reset window.
  Recompute its ETA from the current rate. With no conclusion yet, show
  `newSession` during startup or `measuring` afterwards.
- A clearly safe/risky new reading can change the conclusion immediately.
  UI time alone cannot change evidence or finish startup.

The conclusion is optional Codable state in the existing pace history/cache.
It survives restart and rolling sample pruning. A new reset window, a valid
provider correction (decreased usage), or a different provider discards it.
Legacy caches without this optional field still decode. No new polling or
separate disk writes are introduced.

## Five-hour acceptance scenarios

| Used | Elapsed | Time remaining | Quota remaining | Initial status / English copy |
| --- | --- | --- | --- | --- |
| 0% | 2m | 4h 58m | 100% | No session usage reported yet |
| 1% | 3m | 4h 57m | 99% | New session · measuring pace |
| 2% | 20m | 4h 40m | 98% | At this pace, you should make it to the session reset |
| 10% | 30m | 4h 30m | 90% | Measuring this session's pace, unless a conclusion already exists |
| 40% | 2h | 3h | 60% | Measuring this session's pace, unless a conclusion already exists |
| 25% | 5m | 4h 55m | 75% | At this pace, you could hit the session limit in ~15m |
| 87% | 1h 4m | 3h 56m | 13% | At this pace, you could hit the session limit in ~10m |
| 80% | 4h 50m | 10m | 20% | At this pace, you should make it to the session reset |
| 99% | 4h 55m | 5m | 1% | At this pace, you could hit the session limit in ~3m |
| 100% | 4h 33m | 27m | 0% | Back in 27m; no pace line |

`SessionPaceTransitionTests` asserts these scenarios, exact bilingual copies,
both boundary paths, recovery/worsening, cached data, cache round-trip, rollover,
provider corrections, provider separation and UI-clock behavior. The iOS store
integration test covers restoring cached state and preserving the conclusion
after the next live refresh.
