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

    public init(
        command: String,
        args: [String] = [],
        env: [String: String] = [:],
        serverName: String
    ) {
        self.command = command
        self.args = args
        self.env = env
        self.serverName = serverName
    }
}
