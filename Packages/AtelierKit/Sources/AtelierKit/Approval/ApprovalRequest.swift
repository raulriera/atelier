import Foundation

/// IPC message from the MCP server binary to the app requesting tool approval.
public struct ApprovalRequest: Sendable, Codable {
    public let id: String
    public let toolName: String
    public let inputJSON: String

    public init(id: String, toolName: String, inputJSON: String) {
        self.id = id
        self.toolName = toolName
        self.inputJSON = inputJSON
    }
}

/// IPC response from the app to the MCP server binary.
struct ApprovalResponse: Sendable, Codable {
    let behavior: String
    let message: String?
}
