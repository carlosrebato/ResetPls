import AIUsageCore
import Foundation
import Testing

struct ProjectLinksTests {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test func macFeedAndWebsiteDownloadsUseThePublicReleaseRepository() throws {
        let plistData = try Data(contentsOf: repositoryRoot.appendingPathComponent("Configurations/AIUsageMac-Info.plist"))
        let plist = try #require(PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any])
        #expect(plist["SUFeedURL"] as? String == "https://raw.githubusercontent.com/carlosrebato/ResetPls/main/appcast.xml")
        #expect(plist["SUPublicEDKey"] as? String == "I2g7lb6TRxpoTKuo4VM1wlU+DM+/gNj2KQrFccmzLpY=")
        #expect(plist["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(plist["SUAutomaticallyUpdate"] as? Bool == true)
        for path in ["landing/index.html", "landing/en/index.html", "landing/es/index.html"] {
            let html = try String(contentsOf: repositoryRoot.appendingPathComponent(path), encoding: .utf8)
            #expect(html.contains("https://github.com/carlosrebato/ResetPls/releases/download/"))
            #expect(!html.contains("github.com/carlosrebato/ai-usage-mac"))
        }
    }

    @Test func bothPlatformsUseThePublicSourceRepositoryForSupport() {
        #expect(ProjectLinks.repository == "https://github.com/carlosrebato/ResetPls")
        #expect(ProjectLinks.help == ProjectLinks.repository + "#readme")
        #expect(ProjectLinks.privacy == ProjectLinks.repository + "/blob/main/PRIVACY.md")
        #expect(ProjectLinks.reportIssue == ProjectLinks.repository + "/issues/new/choose")
        for link in [ProjectLinks.repository, ProjectLinks.website,
                     ProjectLinks.help, ProjectLinks.privacy, ProjectLinks.reportIssue] {
            #expect(URL(string: link)?.scheme == "https")
            #expect(!link.contains("/releases") && !link.contains("appcast"))
        }
    }
}
