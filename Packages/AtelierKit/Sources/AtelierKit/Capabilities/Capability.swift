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
    /// Tool groups that can be independently enabled or disabled.
    /// When empty, the capability has a single on/off toggle with no granular control.
    public let toolGroups: [ToolGroup]

    public init(
        id: String,
        name: String,
        description: String,
        iconSystemName: String,
        serverConfig: MCPServerConfig,
        toolGroups: [ToolGroup] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconSystemName = iconSystemName
        self.serverConfig = serverConfig
        self.toolGroups = toolGroups
    }
}
