import XCTest
import SwiftUI
import AIUsageCore
import AIUsageProviderServices
@testable import CaptureIOS

private struct CaptureAdapter: DirectUsageAdapter {
 let providerID: UsageProviderID
 let snapshot: ProviderUsageSnapshot
 func fetchSnapshot() async throws -> ProviderUsageSnapshot { snapshot }
}
@MainActor final class IOSCaptureTests: XCTestCase {
 func testExportNativeDashboard() async throws {
  UserDefaults.standard.setVolatileDomain([AppLanguage.preferenceKey:"es"], forName:UserDefaults.argumentDomain)
  let now=Date.now
  let snapshots = landingSnapshots(now: now)
  let base=FileManager.default.temporaryDirectory.appendingPathComponent("landing-fixtures-" + UUID().uuidString,isDirectory:true)
  try FileManager.default.createDirectory(at:base,withIntermediateDirectories:true)
  let history=UsageHistoryCache(fileURL:base.appendingPathComponent("history.json"))
  for day in 0..<7 {
   let date=now.addingTimeInterval(Double(day-6)*86400)
   let readings=UsageProviderID.allCases.enumerated().map { i,id in
    ProviderUsageSnapshot(id:id,session:UsageWindow(usedPercent:Double([22,31,19,46,38,51,43][day]+i*8),resetsAt:date.addingTimeInterval(7200)),weekly:UsageWindow(usedPercent:36,resetsAt:date.addingTimeInterval(86400)),observedAt:date,source:.live,message:nil)
   }
   _ = try history.recording(readings,at:date)
  }
  let cache = LastKnownCache(fileURL:base.appendingPathComponent("cache.json"))
  try cache.save(snapshots)
  let store=IOSUsageStore(claude:CaptureAdapter(providerID:.claude,snapshot:snapshots[0]),codex:CaptureAdapter(providerID:.codex,snapshot:snapshots[1]),cache:cache,historyCache:history)
  await store.refresh(force:true)
  XCTAssertEqual(store.snapshots[0].paceEstimate(at: now), .onTrackToReset)
  XCTAssertEqual(store.snapshots[1].paceEstimate(at: now), .limitIn(1800, quota: .session))
  let root=IOSDashboardView().environmentObject(store).environment(\.locale,Locale(identifier:"es_ES"))
  let host=UIHostingController(rootView:root)
  let scene=try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
  let window=UIWindow(windowScene:scene)
  window.frame=CGRect(x:0,y:0,width:402,height:874)
  window.overrideUserInterfaceStyle = .dark
  window.rootViewController=host
  window.makeKeyAndVisible()
  host.view.setNeedsLayout()
  host.view.layoutIfNeeded()
  try await Task.sleep(for:.seconds(1))
  let format=UIGraphicsImageRendererFormat()
  format.scale=3
  let image=UIGraphicsImageRenderer(bounds:window.bounds,format:format).image { _ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true) }
  let output=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("iphone-native.png")
  try XCTUnwrap(image.pngData()).write(to:output)
  print("LANDING_CAPTURE_PATH="+output.path)
  XCTAssertEqual(image.size.width,402)
 }
}
