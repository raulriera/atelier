/// Describes a tool exposed by an MCP server.
///
/// Each capability helper returns an array of these from its `allTools()`
/// function. The `MCPServer` converts them to the `tools/list` response format.
public struct ToolDefinition: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: AnyCodableValue

    public init(name: String, description: String, inputSchema: AnyCodableValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}
