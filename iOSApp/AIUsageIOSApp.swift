import SwiftUI
import BackgroundTasks
import AIUsageProviderServices
import WidgetKit

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
            if phase == .background {
                scheduleBackgroundRefresh()
                WidgetCenter.shared.reloadAllTimelines()
            }
            guard phase == .active, refreshOnActivation else { return }
            Task { await store.refresh(force: true) }
        }
        .backgroundTask(.appRefresh("crbg.resetpls.refresh")) {
            await MainActor.run { scheduleBackgroundRefresh() }
            _ = try? await SharedUsageRefresh.shared.refresh(context: "background")
            if !Task.isCancelled { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    private func scheduleBackgroundRefresh() {
        guard !store.isDemoMode else { return }
        let request = BGAppRefreshTaskRequest(identifier: "crbg.resetpls.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        // Earliest date is a request, not a timer. iOS chooses when to run it.
        UserDefaults.standard.set(Date.now, forKey: "iosBackgroundRefreshRequestedAt")
        do {
            try BGTaskScheduler.shared.submit(request)
            UserDefaults.standard.set(true, forKey: "iosBackgroundRefreshScheduled")
            UserDefaults.standard.removeObject(forKey: "iosBackgroundRefreshScheduleError")
        } catch {
            UserDefaults.standard.set(false, forKey: "iosBackgroundRefreshScheduled")
            UserDefaults.standard.set((error as NSError).code, forKey: "iosBackgroundRefreshScheduleError")
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
