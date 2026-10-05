import AIUsageCore
import Foundation
import Testing

struct ProjectLinksTests {
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
