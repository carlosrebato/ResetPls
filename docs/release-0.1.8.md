# ResetPls 0.1.8 (56) — 2026-10-13

- Includes the approved settings, connection/token-history state and bilingual
  copy cleanup, shared privacy notice, iPhone-only declaration and final audit
  widget corrections since build 55.
- 185 shared/Mac/provider tests passed; signed iPhone and universal Mac archives
  succeeded. No simulator was booted for this release.
- iOS upload returned `Upload succeeded` and `EXPORT SUCCEEDED`.
- Mac Developer ID export accepted by Apple notarization:
  `f1a19ec8-36a3-4c7c-bfd7-50d94aa7b3b9`. Ticket stapled and validated;
  Gatekeeper accepted. The universal executable contains arm64 and x86_64.
- Sparkle archive signed using the existing Keychain key and published through
  the existing ResetPls release/feed URLs. No credentials are stored here.

Device behavior remains covered by the owner’s ongoing physical-iPhone testing;
this release does not claim a new physical-device background-refresh test.
