import Foundation

/// A built-in capability that Atelier can enable to give Claude access
/// to external applications via an MCP server.
public struct Capability: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let iconSystemName: String
    /// Resolved at runtime by ``CapabilityRegistry``.
    public let serverConfig: MCPServerConfig

    public init(
        id: String,
        name: String,
        description: String,
        iconSystemName: String,
        serverConfig: MCPServerConfig
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconSystemName = iconSystemName
        self.serverConfig = serverConfig
    }
}
