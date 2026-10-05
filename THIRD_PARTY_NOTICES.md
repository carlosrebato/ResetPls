# Third-party notices

The root MIT license covers original ResetPls source, not ownership of
third-party artwork, trademarks, system assets, or dependencies. Forks must
review the applicable terms before using them in their own marketing.

## Dependencies

- Sparkle is fetched by Swift Package Manager, not vendored here. Its MIT
  license and bundled BSD/zlib-style third-party notices must remain with
  distributed Sparkle binaries: https://github.com/sparkle-project/Sparkle/blob/2.9.6/LICENSE
- The landing uses Vite and its locked transitive dependencies. Their upstream
  licenses remain applicable; `landing/package-lock.json` identifies versions.
- Apple SDKs, frameworks and SF Symbols are governed by Apple's developer and
  system-asset terms, not the project's MIT license.

## Provider identity and marketing artwork

- Claude/Anthropic and Codex/OpenAI names and provider marks identify the
  services supported by this independent app. Their inclusion does not grant
  trademark rights or imply affiliation, sponsorship or endorsement.
- App Store badge artwork under `landing/public/` comes from Apple's official
  marketing tools and remains subject to Apple's marketing artwork terms:
  https://developer.apple.com/app-store/marketing/guidelines/
  The current landing has no App Store listing destination. Do not treat its
  placeholder badge as evidence of an available App Store product, or reuse
  the badge as MIT-licensed artwork. Verify listing availability and badge use
  before a landing launch.
- Ko-fi artwork identifies the creator's support link. It remains Ko-fi brand
  artwork, not MIT-licensed imagery: https://more.ko-fi.com/brand-assets
- Native interface captures use synthetic accounts/counters, not customer
  screenshots. Reproduction details are in
  `landing/public/native/PROVENANCE.md`; third-party marks visible in those
  captures retain their respective rights.

## Device frames excluded from Git

The following files are ignored and absent from both tracked source and its
reachable history:

- `landing/public/iphone-17.png`
- `landing/public/macbook-pro-hd.avif`
- `landing/public/macbook-pro.png`

Mobile FIRST permits personal/commercial mockup use but prohibits redistribution
of the standalone frame: https://www.webmobilefirst.com/en/mockups/apple-iphone-17-2025/
Reely advertises free mockup exports; that is not an open-source license for
redistributing the standalone artwork: https://getreely.co/tools/macbook-mockup-generator

Supply appropriately licensed frames separately for the deployed landing, or
replace them with original/redistributable artwork. Publishing this source
repository does not grant permission to add these excluded binaries.
