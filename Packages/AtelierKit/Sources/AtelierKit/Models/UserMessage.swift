public struct UserMessage: Sendable, Codable {
    public var text: String
    public var attachments: [FileAttachment]

    public init(text: String, attachments: [FileAttachment] = []) {
        self.text = text
        self.attachments = attachments
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        attachments = try container.decodeIfPresent([FileAttachment].self, forKey: .attachments) ?? []
    }
}
