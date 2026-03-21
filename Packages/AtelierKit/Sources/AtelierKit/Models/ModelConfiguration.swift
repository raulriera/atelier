public struct ModelConfiguration: Sendable, Codable, Identifiable {
    public var id: String { modelId }
    public let modelId: String
    public let displayName: String
    public let friendlyName: String
    public let cliAlias: String

    public init(modelId: String, displayName: String, friendlyName: String, cliAlias: String) {
        self.modelId = modelId
        self.displayName = displayName
        self.friendlyName = friendlyName
        self.cliAlias = cliAlias
    }

    public static let opus = ModelConfiguration(
        modelId: "claude-opus-4-6",
        displayName: "Claude Opus",
        friendlyName: "Thorough",
        cliAlias: "opus"
    )

    public static let sonnet = ModelConfiguration(
        modelId: "claude-sonnet-4-6",
        displayName: "Claude Sonnet",
        friendlyName: "Balanced",
        cliAlias: "sonnet"
    )

    public static let haiku = ModelConfiguration(
        modelId: "claude-haiku-4-5-20251001",
        displayName: "Claude Haiku",
        friendlyName: "Quick",
        cliAlias: "haiku"
    )

    public static let allModels: [ModelConfiguration] = [.opus, .sonnet, .haiku]
    public static let `default`: ModelConfiguration = .opus
}
