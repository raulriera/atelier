public struct UserMessage: Sendable, Codable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}
