# Native interface assets — 2026-10-01

- `mac-menubar.png`: neutral macOS menu rendered with SwiftUI, standard SF Symbols, and the original `MenuBarUsageImageContent` extracted from the app source. Finder menus, battery, Wi-Fi, Control Center and a fixed date. No personal desktop screenshot or third-party status items. Regenerated at 6× (8640×168) on 2026-10-02 for the enlarged hero and Retina displays.
- `mac-compact.png`: SwiftUI ImageRenderer, original `App/MenuBarView.swift`, compact state, 3×.
- `mac-expanded.png`: the same original MenuBarView, expanded state, 3×.
- `mac-floating.png`: original `App/FloatingPanelView.swift`, 3×.
- `iphone-native.png`: original `IOSDashboardView.swift` and `IOSUsageStore.swift`, executed by an XCTest capture harness in an iPhone 17 simulator. Rendered from the native UIWindow at 402×874 points, 3×.

Panels use synthetic provider data (37% Claude, 75% Codex), isolated adapters/caches, and no real account credentials. Mac screenshot harness replaces only service dependencies with fixture stores; it copies the views and design-system components from the app source. iOS uses the original store with fixture adapters. No live provider API calls are needed. Three samples over 24 minutes produce an on-track estimate for Claude and a session-limit estimate of ~30m for Codex, using the app's original pace calculation. The landing capture harness shortens the Spanish limit warning to ‘Límite en ~30m’ across all views.

Reproduction sources: `landing/scripts/native-captures/`. `prepare.py` copies current native sources into `/private/tmp/resetpls-landing-captures`; production app files are not edited. Capture provenance is native view rendering, not screenshots of an authenticated session.
