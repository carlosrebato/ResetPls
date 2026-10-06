# TestFlight 0.1.7 (51)

Source commit: `b0668a2`. App and widget extension both use build 51.

## Included

- Small widget: RESET in both languages; bounded countdown text inside the ring.
- WidgetKit gallery: fresh, deterministic sample readings and history rather than
  expired samples that render update failures.
- Service selector: concrete Claude default, editable Claude/Codex options,
  optional static AppIntent metadata. No automatic/first-connected option.
- iOS Settings: Export diagnostic through the system share sheet. The report
  allowlists usage windows, timestamps, status, versions and token availability;
  it excludes credentials, conversation text and raw provider responses.
- iOS token help explains that direct provider APIs do not supply the local
  token history available on Mac.

## Verification and limitations

- iOS tests: 11 passed. Provider OAuth/normalizer tests: 11 passed, including
  Claude reset timestamp formats. Mac compilation passed.
- Small spacing and real WidgetKit gallery reviewed in a dedicated simulator.
- Diagnostic share sheet opened successfully in that simulator.
- Release device archive compiled and signed successfully for upload.
- Explicit service selection remains inconclusive: the native editor saved
  Codex, but the installed widget did not reliably reflect the choice in the
  simulator. Do not describe that behavior as verified or fixed. Legacy widgets
  with an automatic choice may need re-adding; device testing is still needed.
- The missing Claude reset on the user's iPhone is not diagnosed yet. Obtain
  the new diagnostic from the physical device; passing timestamp tests does not
  prove its provider response contains a reset.
- iOS token totals remain unavailable; no values are fabricated.
- Lock Screen layouts/backgrounds are unchanged in this build. Their editing
  outlines and tint belong to iOS, not a new panel design.

The user explicitly requested uploading this build with these pending checks
so they can test on their iPhone. Upload acceptance and Apple processing status
must be reported separately.
