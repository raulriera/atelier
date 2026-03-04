import Foundation

/// Configuration for launching an MCP server as a child process.
public struct MCPServerConfig: Codable, Sendable, Equatable {
    /// The absolute path to the server executable.
    public let command: String
    /// Arguments passed to the executable.
    public let args: [String]
    /// Environment variables set for the process.
    public let env: [String: String]
    /// The key used in the `mcpServers` dictionary of the MCP config JSON.
    public let serverName: String
    /// Tool names that should be auto-approved when this capability is enabled.
    /// Each name is the bare tool name (e.g. `keynote_create_presentation`);
    /// it will be prefixed with `mcp__{serverName}__` at argument-building time.
    public let autoApproveTools: [String]

    public init(
        command: String,
        args: [String] = [],
        env: [String: String] = [:],
        serverName: String,
        autoApproveTools: [String] = []
    ) {
        self.command = command
        self.args = args
        self.env = env
        self.serverName = serverName
        self.autoApproveTools = autoApproveTools
    }
}
