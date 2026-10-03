from pathlib import Path
import shutil
repo=Path(__file__).resolve().parents[3]
source=repo
out=Path('/private/tmp/resetpls-landing-captures')
(out/'Sources/Capture').mkdir(parents=True,exist_ok=True)
for name in ['AIUsageCore','AIUsageDesignSystem','AIUsageProviderServices']:
 shutil.copytree(source/'Sources'/name,out/'Sources'/name,dirs_exist_ok=True)
# Keep the landing's warning concise in every native capture (Mac and iPhone).
pace=out/'Sources/AIUsageCore/UsagePace.swift'
pace.write_text(pace.read_text().replace(
 '"A este ritmo: \\(label) en \\(UsagePaceFormatter.string(duration: duration))"',
 '"Límite en \\(UsagePaceFormatter.string(duration: duration))"'
))
for name in ['MenuBarView.swift','FloatingPanelView.swift']:
 text=(source/'App'/name).read_text().replace('import AIUsageMacServices\n','')
 (out/'Sources/Capture'/name).write_text(text)
helper=(source/'App/DashboardView.swift').read_text().split('struct UsageHeaderFreshnessLine: View {',1)[1]
(out/'Sources/Capture/Freshness.swift').write_text('import SwiftUI\nimport AIUsageCore\nimport AIUsageDesignSystem\nstruct UsageHeaderFreshnessLine: View {'+helper)
for name in ['Fixtures.swift','FixtureData.swift','Capture.swift']:
 shutil.copy(Path(__file__).parent/name,out/'Sources/Capture'/name)
(out/'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ResetPlsCaptures", platforms: [.macOS(.v15), .iOS(.v18)], products: [
.library(name: "AIUsageCore", targets: ["AIUsageCore"]),
.library(name: "AIUsageDesignSystem", targets: ["AIUsageDesignSystem"]),
.library(name: "AIUsageProviderServices", targets: ["AIUsageProviderServices"])
], targets: [
.target(name: "AIUsageCore"),
.target(name: "AIUsageDesignSystem", dependencies: ["AIUsageCore"], resources: [.process("Resources")]),
.target(name: "AIUsageProviderServices", dependencies: ["AIUsageCore"]),
.executableTarget(name: "Capture", dependencies: ["AIUsageCore", "AIUsageDesignSystem"])
])
''')
shutil.copytree(source/'iOSApp',out/'iOSApp',dirs_exist_ok=True)
print(out)
shutil.copy(Path(__file__).parent/'IOSCaptureHost.swift', out/'iOSApp/AIUsageIOSApp.swift')
(out/'Tests').mkdir(exist_ok=True)
shutil.copy(Path(__file__).parent/'IOSCaptureTests.swift', out/'Tests/IOSCaptureTests.swift')
shutil.copy(Path(__file__).parent/'project.yml',out/'project.yml')

menu=(source/'App/AIUsageMacApp.swift').read_text().split('private struct MenuBarUsageImageContent: View {',1)[1]
(out/'Sources/Capture/MenuBarContent.swift').write_text('import SwiftUI\nimport AIUsageCore\nimport AIUsageDesignSystem\nprivate let menuBarLabelHeight: CGFloat = 19\nstruct MenuBarUsageImageContent: View {'+menu)

shutil.copy(Path(__file__).parent/"FixtureData.swift", out/"Tests/FixtureData.swift")

# Capture the actual widget view in its supported small and medium layouts.
widget=(source/'Widgets/AIUsageWidgets.swift').read_text().split('@main')[0]
widget=widget.replace('private struct UsageWidgetEntry', 'struct UsageWidgetEntry').replace('private struct UsageWidgetView', 'struct UsageWidgetView')
widget=widget.replace(r'@Environment(\.widgetFamily) private var family', 'var family: WidgetFamily = .systemSmall')
(out/'Sources/Capture/Widgets.swift').write_text(widget)
