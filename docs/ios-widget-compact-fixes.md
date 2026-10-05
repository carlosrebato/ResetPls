# Compact iOS widgets: configuration and inline rendering

## Observed on build 49

- Small and circular widgets remained at the system-redacted placeholder while
  summary widgets already showed real account data.
- Inline showed only the first service, with an oversized provider image.
- Rectangular values and reset times needed stronger legibility.

## Changes

- The service intent is no longer file-private and uses a nonoptional static
  AppEnum parameter with an explicitly declared `automatic` default. Automatic
  selects the first available service in the saved display order; an explicit
  Claude/Codex selection is respected. Existing enum choices and widget kinds
  are preserved.
- Build 49's extracted parameter metadata had `isOptional: true`, dynamic
  options, and no default. The new generated metadata has `isOptional: false`,
  no dynamic options, and the default value `automatic`. This removes dynamic
  option resolution from first placement; actual device timeline recovery
  still needs validation. Placeholder redaction is not disabled or disguised
  with preview numbers.
- Inline uses one Text payload with embedded provider image attachments, not
  an HStack of separately extracted text/image views. Provider images are
  rendered to 14-point natural dimensions before being embedded, so the host
  does not need to honor frame/resizable modifiers. Both providers remain in
  the text payload; extra time is only included for a single provider.
- Rectangular percentages are 15pt, provider marks 13pt, and reset times 10pt
  with stronger opacity and a bounded single line. Medium/large layout is
  unchanged. Widgets respect the saved provider order.
- The in-app gallery uses the corrected inline construction and rectangular
  typography, instead of a misleading multi-view inline approximation.

## Verification

- iOS suite: 10 passed, 0 failed on iPhone 17 Pro Max / iOS 26.5 simulator.
- The new image-rendering test checks both provider attachments individually
  and the combined two-provider text line for bounded width/height.
- macOS app/widget compilation passed.
- Generated App Intents metadata default/optionality assertions passed.

Before declaring the reported placeholder bug resolved, validate new and
existing small/circular widgets and the two-provider inline widget on the
physical iPhone using the next TestFlight build. Build 49 is unchanged.
