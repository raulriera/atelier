public struct SystemEvent: Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case sessionStarted
        case error
    }

    public var kind: Kind
    public var message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}
