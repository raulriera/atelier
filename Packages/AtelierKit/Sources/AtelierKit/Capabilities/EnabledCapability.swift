import Foundation

/// An enabled capability paired with its approved tool names.
///
/// Used to pass capability configuration from ``CapabilityStore`` through
/// ``ConversationEngine`` to ``CLIEngine`` for argument building.
public struct EnabledCapability: Sendable {
    /// The MCP server configuration for this capability.
    public let config: MCPServerConfig
    /// Bare tool names approved by the user's group selections.
    public let approvedTools: [String]

    public init(config: MCPServerConfig, approvedTools: [String]) {
        self.config = config
        self.approvedTools = approvedTools
    }
}
