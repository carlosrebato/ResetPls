# ResetPls black icon — 2026-11-03 correction

Carlos requested removal of the white highlights at the top/bottom on iOS and the thick gray frame shown by Finder. This supersedes the reflective rim in option A; Placeclock remains untouched.

## Active source
- `App/ResetPlsIcon.icon`: native Icon Composer bundle used by both app targets.
- Solid black canvas, opaque artwork, layer glass disabled, group specular disabled, translucency disabled, shadow opacity zero.
- `Assets/ResetPlsBlack.png` is the production artwork; `docs/brand/resetpls-icon-black.png` is a matching master copy.
- The older approved-A master is retained for reference only.
- Raster exports and the in-app brand images can be refreshed from the repository root with `swift Scripts/export-icon-rasters.swift`. App icons for current and older OS versions are compiled by Xcode from the native bundle.

## Image edit
Built-in image generation edited the approved-A master. Prompt: remove metallic rim, white/gray highlights, reflections and bevel; extend black to every edge/corner; retain the central green dot, halo and circular ripple. The image is opaque and contains no white edge pixels.

## Verification
- macOS build 68: inspected the app icon in Finder both before and after installation. The thick gray/white frame is gone.
- iOS build 68: inspected in the iOS 27 simulator App Library. Black background without the previous white top/bottom marks. Spotlight can show a selection outline; this is not part of the image.
- Signed Mac build and signed iOS Release archive passed deep/strict signature verification.
- Mac app and data were backed up before installing; history remains schema 1 with 59 days.
