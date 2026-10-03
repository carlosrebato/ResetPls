import AIUsageCore
import AuthenticationServices
import Foundation
import Network
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
public final class ProviderWebAuthentication: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = ProviderWebAuthentication()

    private var webSession: ASWebAuthenticationSession?
    private var loopback: OAuthLoopbackServer?

    public func signIn(_ provider: UsageProviderID) async throws {
        switch provider {
        case .claude:
            try await signInToClaude()
        case .codex:
            try await signInToCodex()
        }
    }

    public func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
#if os(macOS)
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
#else
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
            ?? ASPresentationAnchor()
#endif
    }

    private func signInToClaude() async throws {
        let redirectURI = "https://platform.claude.com/oauth/code/callback"
        let account = ProviderAccounts.shared.claude
        let request = try await account.authorizationRequest(redirectURI: redirectURI)
        let callbackURL = try await webCallback(
            authorizationURL: request.authorizationURL,
            callback: .https(host: "platform.claude.com", path: "/oauth/code/callback")
        )
        try await account.completeAuthorization(callbackURL: callbackURL, request: request)
    }

    private func signInToCodex() async throws {
        let server = OAuthLoopbackServer()
        loopback = server
        defer {
            server.cancel()
            loopback = nil
        }
        let port = try await server.start(preferredPorts: [1455, 1457])
        let redirectURI = "http://localhost:\(port)/auth/callback"
        let account = ProviderAccounts.shared.codex
        let request = try await account.authorizationRequest(redirectURI: redirectURI)

        let session = ASWebAuthenticationSession(
            url: request.authorizationURL,
            callbackURLScheme: nil
        ) { [weak server] _, error in
            if error != nil { server?.cancel() }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webSession = session
        guard session.start() else {
            webSession = nil
            throw ProviderOAuthError.invalidAuthorizationResponse
        }
        defer {
            session.cancel()
            webSession = nil
        }
        let callbackURL = try await server.waitForCallback()
        try await account.completeAuthorization(callbackURL: callbackURL, request: request)
    }

    private func webCallback(
        authorizationURL: URL,
        callback: ASWebAuthenticationSession.Callback
    ) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: authorizationURL,
                    callback: callback
                ) { [weak self] callbackURL, error in
                    self?.webSession = nil
                    if let callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: error ?? ProviderOAuthError.invalidAuthorizationResponse)
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                webSession = session
                guard session.start() else {
                    webSession = nil
                    continuation.resume(throwing: ProviderOAuthError.invalidAuthorizationResponse)
                    return
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.webSession?.cancel()
                self?.webSession = nil
            }
        }
    }
}

private final class OAuthLoopbackServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.carlosrebato.aiusage.oauth-loopback")
    private var listener: NWListener?
    private var startCallback: CheckedContinuation<UInt16, Error>?
    private var callback: CheckedContinuation<URL, Error>?
    private var pendingResult: Result<URL, Error>?
    private var finished = false

    func start(preferredPorts: [UInt16]) async throws -> UInt16 {
        var lastError: Error?
        for value in preferredPorts {
            do {
                return try await start(port: value)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? ProviderOAuthError.invalidAuthorizationResponse
    }

    func waitForCallback() async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    if let pending = self.pendingResult {
                        self.pendingResult = nil
                        continuation.resume(with: pending)
                    } else if self.finished {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        self.callback = continuation
                        self.queue.asyncAfter(deadline: .now() + 300) {
                            self.finish(.failure(URLError(.timedOut)))
                        }
                    }
                }
            }
        } onCancel: {
            cancel()
        }
    }

    func cancel() {
        queue.async { self.finish(.failure(CancellationError())) }
    }

    private func start(port value: UInt16) async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let port = NWEndpoint.Port(rawValue: value)!
                    let parameters = NWParameters.tcp
                    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
                    let listener = try NWListener(using: parameters)
                    self.listener = listener
                    self.startCallback = continuation
                    listener.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            guard let callback = self.startCallback else { return }
                            self.startCallback = nil
                            callback.resume(returning: value)
                        case .failed(let error):
                            guard let callback = self.startCallback else { return }
                            self.startCallback = nil
                            listener.cancel()
                            self.listener = nil
                            callback.resume(throwing: error)
                        default:
                            break
                        }
                    }
                    listener.newConnectionHandler = { [weak self] connection in
                        self?.handle(connection)
                    }
                    listener.start(queue: self.queue)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) {
            [weak self] data, _, _, _ in
            guard let self else { return }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            guard let url = Self.callbackURL(from: request) else {
                Self.respond(connection, status: "404 Not Found", body: "Not found")
                return
            }
            Self.respond(
                connection,
                status: "200 OK",
                body: "<h2>Connected</h2><p>You can return to AI Usage.</p>"
            )
            self.finish(.success(url))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !finished else { return }
        finished = true
        listener?.cancel()
        listener = nil
        if let callback {
            self.callback = nil
            callback.resume(with: result)
        } else {
            pendingResult = result
        }
    }

    private static func callbackURL(from request: String) -> URL? {
        guard let firstLine = request.split(separator: "\r\n").first,
              let target = firstLine.split(separator: " ").dropFirst().first,
              target.hasPrefix("/auth/callback")
        else { return nil }
        return URL(string: "http://localhost\(target)")
    }

    private static func respond(_ connection: NWConnection, status: String, body: String) {
        let html = "<html><body style=\"font-family:-apple-system;padding:4em;text-align:center\">\(body)</body></html>"
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
