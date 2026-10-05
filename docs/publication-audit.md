# ResetPls source publication review — 2026-10-05

Scope: `carlosrebato/ResetPls`, originally private. This review does not publish
a new app release, deploy the landing or migrate the existing Sparkle feed.

## Evidence checked

- Root MIT license already exists; no new license choice was made.
- Gitleaks 8.30.1 (official release checksum verified) reported no secrets in
  the tracked source tree or all 28 reachable commits, including remote
  Dependabot branches. Automated scanning is a check, not proof of absence.
- Git object/path inspection found no credential files, local conversation
  logs, local databases, or excluded standalone device-frame binaries.
- All 19 existing Actions logs were scanned with no secrets reported. No release
  assets exist in this repository. The ten current Actions artifacts are
  unsigned app builds produced by the ordinary build workflow, not customer
  diagnostic exports.
- OAuth client identifiers, Apple team identifiers and Sparkle verification
  keys in source are public configuration, not private credentials. Signing
  certificates, private keys and account tokens are not committed.
- Commit authorship contains the maintainer's name/email, as in the previous
  public repository. CI logs contain hosted-runner/build metadata.
- Native landing captures have documented synthetic-data provenance. Marketing
  artwork and provider marks are not relicensed as MIT; see
  `THIRD_PARTY_NOTICES.md`. Standalone device frames remain excluded.
- Source publication does not change either update channel, any installed
  app's data, or the existing public release repository.

## Publication checks

- Verify repository visibility is public after the explicitly requested change.
- Verify a complete successful CodeQL run, including result upload. The missing
  `actions: read` permission has been added; a manual trigger permits a fresh
  run after the visibility change without another app build/version change.
  Both Mac and iOS apps are built under CodeQL to cover both platform targets.
- Verify normal CI and the new redacted source/history secret scan pass.
- Enable private vulnerability reporting and maintain branch protections.

## Separate product-release work

- App Store listing/review and compliant badge destination remain separate.
- Obtain redistributable frame artwork if standalone frames are ever added to
  the repository; do not confuse allowed web mockup use with redistribution.
- Follow the signed bridge-update tests in `MIGRATION.md` before moving feeds.
