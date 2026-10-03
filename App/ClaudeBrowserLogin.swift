import AIUsageCore
import AIUsageProviderServices

@MainActor
enum ClaudeBrowserLogin {
    static func signIn() async throws {
        try await ProviderWebAuthentication.shared.signIn(.claude)
    }
}
