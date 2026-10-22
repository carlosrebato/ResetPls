/// Ignore initial online delivery and duplicate path notifications. An actual
/// offline-to-online transition can schedule one debounced recovery attempt.
public struct NetworkRecoveryTransition: Sendable {
    private var wasConnected: Bool?

    public init() {}

    public mutating func update(isConnected: Bool) -> Bool {
        defer { wasConnected = isConnected }
        return wasConnected == false && isConnected
    }
}
