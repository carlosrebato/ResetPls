import Foundation

public enum UsageRefreshDisposition: Equatable, Sendable {
    case current, saved, failed
}

extension ProviderUsageSnapshot {
    public func refreshDisposition(evidence: UsageRefreshEvidence?, at now: Date) -> UsageRefreshDisposition {
        if evidence?.failed(after: observedAt) == true { return .failed }
        return source == .cached || isStale(at: now) ? .saved : .current
    }
}

/// Non-sensitive evidence, separate from the age/source of a saved reading.
public struct UsageRefreshEvidence: Codable, Equatable, Sendable {
    public var attemptedAt: Date
    public var succeededAt: Date?
    public var failedAt: Date?
    public var retryAt: Date?
    public var context: String
    public var errorCode: String?

    public init(attemptedAt: Date, succeededAt: Date? = nil, failedAt: Date? = nil,
                retryAt: Date? = nil, context: String, errorCode: String? = nil) {
        self.attemptedAt = attemptedAt
        self.succeededAt = succeededAt
        self.failedAt = failedAt
        self.retryAt = retryAt
        self.context = context
        self.errorCode = errorCode
    }

    public func failed(after observation: Date) -> Bool {
        guard let failedAt else { return false }
        return failedAt >= observation && failedAt > (succeededAt ?? .distantPast)
    }
}

public struct UsageRefreshEvidenceCache: Sendable {
    public let fileURL: URL
    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? UsageSnapshotCache().fileURL.deletingLastPathComponent()
            .appendingPathComponent("refresh-evidence.json")
    }
    public func load() -> [UsageProviderID: UsageRefreshEvidence] {
        guard let data = try? Data(contentsOf: fileURL),
              let values = try? JSONDecoder().decode([UsageProviderID: UsageRefreshEvidence].self, from: data)
        else { return [:] }
        return values
    }
    public func save(_ values: [UsageProviderID: UsageRefreshEvidence]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: fileURL, options: .atomic)
    }
}
