# Canonical project links — 2026-10-08

| Destination | Canonical URL | Consumers |
| --- | --- | --- |
| Source | https://github.com/carlosrebato/ResetPls | Web header/footer, repository references |
| Help | https://github.com/carlosrebato/ResetPls#readme | Mac and iOS settings |
| Privacy (English) | https://resetpls.app/privacy/ | English web FAQ/footer, shared Mac and iOS settings link from next build, App Store privacy URL |
| Privacy (Spanish) | https://resetpls.app/es/privacy/ | Spanish web FAQ/footer, language link from English policy |
| Issue reports | https://github.com/carlosrebato/ResetPls/issues/new/choose | Web footer, Mac and iOS settings |
| Website | https://resetpls.app | GitHub repository homepage |
| Mac downloads | https://github.com/carlosrebato/ResetPls/releases | README and landing download buttons |
| Sparkle feed | https://raw.githubusercontent.com/carlosrebato/ResetPls/main/appcast.xml | Mac build 48 onward, stable and beta channels |

Native support URLs share `AIUsageCore.ProjectLinks` so Mac and iOS do not
diverge. The web's `/`, `/en/` and `/es/` entrypoints use the same destinations.

The uploaded iOS build 53 and already installed Mac still contain the previous
GitHub policy link. The shared source now uses `/privacy/`; changing website
content does not retroactively update a shipped binary. Both policy pages are
public static HTML, with explicit language links and no login requirement.

The old repository is private by the owner's explicit choice. Existing clients
must install build 48 manually once; their old feed can no longer be read
anonymously. The new app preserves the signing identity, Sparkle key and saved
stable/beta selection. See `MIGRATION.md` for the cutover details.

The App Store destination is still pending a listing URL. No listing is
invented as part of publishing the source repository.
