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

// MARK: - Ask User IPC

/// IPC message from the MCP server binary requesting a user choice.
public struct AskUserIPCRequest: Sendable, Codable {
    public struct Option: Sendable, Codable {
        public let label: String
        public let description: String?
    }

    public let requestType: String  // "ask_user"
    public let id: String
    public let question: String
    public let options: [Option]
}

/// IPC response returning the user's selection.
struct AskUserIPCResponse: Sendable, Codable {
    let selectedIndex: Int
    let selectedLabel: String
}

/// Wrapper to peek at the `requestType` field before full decoding.
struct IPCRequestEnvelope: Codable {
    let requestType: String?
}
