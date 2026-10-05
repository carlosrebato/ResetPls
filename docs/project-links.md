# Canonical project links — 2026-10-05

| Destination | Canonical URL | Consumers |
| --- | --- | --- |
| Source | https://github.com/carlosrebato/ResetPls | Web header/footer, repository references |
| Help | https://github.com/carlosrebato/ResetPls#readme | Mac and iOS settings |
| Privacy | https://github.com/carlosrebato/ResetPls/blob/main/PRIVACY.md | Web FAQ/footer, Mac and iOS settings |
| Issue reports | https://github.com/carlosrebato/ResetPls/issues/new/choose | Web footer, Mac and iOS settings |
| Website | https://resetpls.app | GitHub repository homepage |
| Mac downloads | https://github.com/carlosrebato/ai-usage-mac/releases | README and existing landing download buttons |
| Sparkle feed | https://raw.githubusercontent.com/carlosrebato/ai-usage-mac/main/appcast.xml | Existing Mac installations and current configuration |

Native support URLs share `AIUsageCore.ProjectLinks` so Mac and iOS do not
diverge. The web's `/`, `/en/` and `/es/` entrypoints use the same destinations.

Do not replace release/download URLs or feeds by blindly changing repository
names. ResetPls has no replacement signed release yet. Existing channels and
signatures remain intact; a bridge release requires the checks in `MIGRATION.md`.

The App Store destination is still pending a listing URL. No listing is
invented as part of publishing the source repository.
