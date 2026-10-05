# ResetPls landing

From the repository root:

```sh
npm --prefix landing run dev
npm --prefix landing run build
```

Preview: http://127.0.0.1:4173. Static output: `landing/dist`.

Source, privacy and issue-report links point to `carlosrebato/ResetPls`.
Mac downloads use the signed `ResetPls` releases, as does the new Sparkle feed.
See `../docs/project-links.md`.

The device-frame binaries are intentionally not committed. Before deploying this
site, supply `public/macbook-pro-hd.avif` and `public/iphone-17.png` from their
original providers under their respective licenses, or replace them with assets
we can redistribute. A successful Vite build alone does not verify these images
are present.

Five scenes share a MacBook with its right corner as the initial crop. The pinned sequence uses 240 viewport-height percentage units of scrolling plus its visible viewport. Native compact, expanded and floating panel assets replace the former HTML mockups. iPhone uses the native iOS dashboard and a photographic device frame. See `public/native/PROVENANCE.md` for capture provenance and synthetic data details. Reduced-motion preferences disable transitions.

## Reproduce native captures

```sh
python3 landing/scripts/native-captures/prepare.py
swift run --package-path /private/tmp/resetpls-landing-captures Capture "$PWD/landing/public/native"
xcodegen generate --spec /private/tmp/resetpls-landing-captures/project.yml
xcodebuild test -project /private/tmp/resetpls-landing-captures/LandingCaptures.xcodeproj -scheme CaptureIOS -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath /private/tmp/resetpls-landing-ios-build -parallel-testing-enabled NO
```

The iOS test prints `LANDING_CAPTURE_PATH`; copy that PNG to `public/native/iphone-native.png`. Requires Xcode, its iOS runtime, and XcodeGen. The menu strip is a neutral SwiftUI render using system symbols and the original ResetPls status-item view; it contains no personal apps. The capture harness does not change the installed app's preferences or use account credentials.

## Third-party device frames

Mobile FIRST standard transparent PNGs, downloaded 2026-10-01:
- Original MacBook (unused): https://www.webmobilefirst.com/en/mockups/apple-macbook-pro-16-2021/
- iPhone: https://www.webmobilefirst.com/en/mockups/apple-iphone-17-2025/

Personal/commercial use and cropping permitted; attribution not required; resale/redistribution of the standalone frame files prohibited. These frames are not covered by the app source-code license. The original 800px MacBook frame is no longer used by the landing.

## Before publication

Connect the App Store destination. The tip jar links to https://ko-fi.com/crbg_. Mac download links currently point to the project's GitHub releases. Published on Cloudflare Workers: https://resetpls-web.carlos-rebato.workers.dev. Review copy and native screenshot data before publication.

App Store badge: official Spanish black SVG from https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/es-es?size=250x83&releaseDate=0. Link remains pending until the app listing URL is available.

Ko-fi cup logo: https://storage.ko-fi.com/cdn/cup-border.png. Custom transparent button with Spanish copy, linked to the creator profile.

## Deploy

Run `npm --prefix landing run deploy` from the repository root with Wrangler authenticated. Configuration: `wrangler.jsonc`. Worker: `resetpls-web`. Custom domain: https://resetpls.app (Cloudflare-managed DNS and HTTPS).

Scroll choreography interpolates continuously between five camera poses over 240svh: each transition spans 38svh, followed by a 22svh reading pause. The initial transition starts immediately and the final pause keeps the iPhone scene pinned. Device geometry and panel opacity follow scroll position without timed CSS transitions; copy crossfades around scene midpoints. Reduced motion uses discrete poses.

## HD assets — 2026-10-02

The active MacBook frame is `public/macbook-pro-hd.avif` (4340×2860), from Reely’s free full-resolution Mac mockup generator:
https://getreely.co/tools/macbook-mockup-generator
Asset: https://getreely.co/tools/device-mockups/frames/macbook-pro-16-silver.avif
The generator advertises free, watermark-free exports for landing pages and launch materials. The third-party frame is not covered by this app’s source license.
Its native display opening is x=443, y=313, width=3456, height=2234. CSS aligns this with the existing scene’s screen top and right edge without stretching the frame.
The native menu capture is rendered at 6×; other native panels remain at 3×. Avoid forcing `will-change: transform` on the computer: it can cache the scene at its smaller pre-zoom raster size.
