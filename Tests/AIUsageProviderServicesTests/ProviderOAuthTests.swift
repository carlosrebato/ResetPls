import Foundation
import Testing
import AIUsageCore
@testable import AIUsageProviderServices

private final class MemoryVaultStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var value: StoredProviderToken?

    init(_ value: StoredProviderToken? = nil) { self.value = value }
    func load() -> StoredProviderToken? { lock.withLock { value } }
    func save(_ value: StoredProviderToken) { lock.withLock { self.value = value } }
    func clear() { lock.withLock { value = nil } }
}

private struct MemoryVault: ProviderTokenVault {
    let storage: MemoryVaultStorage
    func load() throws -> StoredProviderToken? { storage.load() }
    func save(_ token: StoredProviderToken) throws { storage.save(token) }
    func clear() throws { storage.clear() }
}

private final class OAuthURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() { }
}

@Suite(.serialized)
struct ProviderOAuthTests {
    @Test func claudeUsesTheBlockingLeastPrivilegeScope() {
        #expect(ProviderOAuthConfiguration.claude.scopes == ["user:profile"])
        #expect(!ProviderOAuthConfiguration.claude.scopes.contains("user:" + "inference"))
        #expect(!ProviderOAuthConfiguration.claude.scopes.contains("org:" + "create_api_key"))
    }

    @Test func codexCapabilitiesAreFixedAndDocumented() {
        #expect(ProviderOAuthConfiguration.codex.scopes == [
            "openid", "profile", "email", "offline_access",
            "api.connectors.read", "api.connectors.invoke"
        ])
    }

    @Test func authorizationUsesPKCEAndRandomState() async throws {
        let account = ProviderOAuthAccount(
            configuration: .claude,
            vault: MemoryVault(storage: MemoryVaultStorage()),
            session: testSession()
        )
        let first = try await account.authorizationRequest(
            redirectURI: "https://platform.claude.com/oauth/code/callback"
        )
        let second = try await account.authorizationRequest(
            redirectURI: "https://platform.claude.com/oauth/code/callback"
        )
        let query = URLComponents(url: first.authorizationURL, resolvingAgainstBaseURL: false)?.queryItems
        #expect(first.state != second.state)
        #expect(query?.first { $0.name == "code_challenge_method" }?.value == "S256")
        #expect(query?.first { $0.name == "scope" }?.value == "user:profile")
    }

    @Test func manipulatedCallbackIsRejectedBeforeTokenExchange() async throws {
        let account = ProviderOAuthAccount(
            configuration: .claude,
            vault: MemoryVault(storage: MemoryVaultStorage()),
            session: testSession()
        )
        let request = try await account.authorizationRequest(
            redirectURI: "https://platform.claude.com/oauth/code/callback"
        )
        let callback = URL(string: "https://platform.claude.com/oauth/code/callback?code=secret&state=wrong")!
        await #expect(throws: ProviderOAuthError.stateMismatch) {
            try await account.completeAuthorization(callbackURL: callback, request: request)
        }
    }

    @Test func tenConcurrentCredentialsPerformOneRefreshAndRotateAtomically() async throws {
        let expired = StoredProviderToken(
            accessToken: "expired",
            refreshToken: "refresh-old",
            idToken: nil,
            expiresAt: Date(timeIntervalSince1970: 1),
            accountID: nil,
            scopes: ["user:profile"]
        )
        let storage = MemoryVaultStorage(expired)
        let count = LockedCounter()
        OAuthURLProtocol.handler = { request in
            count.increment()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"access_token":"fresh","refresh_token":"refresh-new","expires_in":3600}"#.utf8))
        }
        let account = ProviderOAuthAccount(
            configuration: .claude,
            vault: MemoryVault(storage: storage),
            session: testSession(),
            now: { Date(timeIntervalSince1970: 100) }
        )

        try await withThrowingTaskGroup(of: ProviderCredential?.self) { group in
            for _ in 0..<10 { group.addTask { try await account.credential() } }
            for try await credential in group { #expect(credential?.accessToken == "fresh") }
        }
        #expect(count.value == 1)
        #expect(storage.load()?.refreshToken == "refresh-new")
    }

    @Test func directNormalizersTolerateAdditionalWindows() throws {
        let claude = try ClaudeDirectUsageNormalizer.snapshot(
            from: Data(#"{"five_hour":{"utilization":25},"seven_day":{"utilization":40},"seven_day_opus":{"utilization":10}}"#.utf8),
            observedAt: .now
        )
        let codex = try CodexDirectUsageNormalizer.snapshot(
            from: Data(#"{"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":22,"limit_window_seconds":18000},"secondary_window":{"used_percent":51,"limit_window_seconds":604800}},"credits":{}}"#.utf8),
            observedAt: .now
        )
        #expect(claude.weekly.usedPercent == 40)
        #expect(codex.session.usedPercent == 22)
        #expect(codex.weekly.usedPercent == 51)
    }

    private func testSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OAuthURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}
