import SwiftUI

@main
struct AIUsageIOSApp: App {
    @StateObject private var store = IOSUsageStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("iosRefreshOnActivation") private var refreshOnActivation = true
    @AppStorage("iosOnboardingCompleted") private var onboardingCompleted = false

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("--show-widget-previews") {
                    IOSWidgetPreviewGallery()
                } else if shouldShowOnboarding {
                    IOSOnboardingView {
                        onboardingCompleted = true
                    }
                    .environmentObject(store)
                } else {
                    IOSDashboardView()
                        .environmentObject(store)
                        .task { await store.refresh() }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, refreshOnActivation else { return }
            Task { await store.refresh(force: true) }
        }
    }

    private var shouldShowOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("--show-onboarding")
            || (!onboardingCompleted
            && !store.isDemoMode
            && !ProcessInfo.processInfo.arguments.contains("--show-settings")
            && !ProcessInfo.processInfo.arguments.contains("--skip-onboarding"))
    }
}
