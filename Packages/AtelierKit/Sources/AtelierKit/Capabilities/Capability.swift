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
    /// An optional hint injected into the system prompt when this capability is enabled.
    /// Use this for safety guidance (e.g. "prefer finder_trash over rm").
    public let systemPromptHint: String?
    /// Whether this capability should be enabled (all groups) on first load
    /// when no persisted state exists.
    public let defaultEnabled: Bool

    public init(
        id: String,
        name: String,
        description: String,
        iconSystemName: String,
        serverConfig: MCPServerConfig,
        toolGroups: [ToolGroup] = [],
        systemPromptHint: String? = nil,
        defaultEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconSystemName = iconSystemName
        self.serverConfig = serverConfig
        self.toolGroups = toolGroups
        self.systemPromptHint = systemPromptHint
        self.defaultEnabled = defaultEnabled
    }
}
