import Foundation

public struct ApprovalEvent: Sendable, Codable, Identifiable {
    public enum Status: String, Sendable, Codable {
        case pending
        case approved
        case denied
        case dismissed
    }

    public let id: String
    public var toolName: String
    public var inputJSON: String
    public var status: Status
    public var decidedAt: Date?

    public init(
        id: String,
        toolName: String,
        inputJSON: String = "",
        status: Status = .pending,
        decidedAt: Date? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.inputJSON = inputJSON
        self.status = status
        self.decidedAt = decidedAt
    }

    // MARK: - Display metadata

    /// A human-readable sentence describing what this approval is for.
    public var plainDescription: String {
        guard let dict = parsedInput else { return displayName }

        switch toolName {
        case "Bash":
            if let desc = dict["description"] as? String, !desc.isEmpty { return desc }
            return "Run a terminal command"

        case "Write":
            if let path = dict["file_path"] as? String, !path.isEmpty {
                return "Create \((path as NSString).lastPathComponent)"
            }
            return "Create a new file"

        case "Edit":
            if let path = dict["file_path"] as? String, !path.isEmpty {
                return "Edit \((path as NSString).lastPathComponent)"
            }
            return "Edit a file"

        case "NotebookEdit":
            return "Edit a notebook"

        default:
            if toolName.hasPrefix("mcp__") {
                let parts = toolName.split(separator: "__")
                if parts.count >= 3 {
                    let tool = parts.last!.replacingOccurrences(of: "_", with: " ")
                    return tool.capitalized
                }
            }
            return displayName
        }
    }

    /// User-friendly display name describing what Claude wants to do.
    public var displayName: String {
        switch toolName {
        case "Bash": "Run Terminal Command"
        case "Write": "Write File"
        case "Edit": "Edit File"
        case "NotebookEdit": "Edit Notebook"
        default: "Use \(toolName)"
        }
    }

    /// SF Symbol name for the approval card.
    public var iconName: String {
        switch toolName {
        case "Write": "doc.badge.plus"
        case "Edit": "pencil"
        case "Bash": "terminal"
        case "NotebookEdit": "book"
        default: "wrench"
        }
    }

    /// Parses `inputJSON` into a dictionary.
    private var parsedInput: [String: Any]? {
        guard let data = inputJSON.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// A short summary of the tool's input for display.
    public var inputSummary: String {
        guard let dict = parsedInput else { return "" }

        let value: String? = switch toolName {
        case "Write", "Edit":
            dict["file_path"] as? String
        case "Bash":
            dict["command"] as? String
        default:
            dict.values.first.flatMap { $0 as? String }
        }

        guard let value, !value.isEmpty else { return "" }
        if value.count <= 80 { return value }
        return String(value.prefix(77)) + "..."
    }

    /// The file path extracted from `inputJSON`, if applicable.
    public var filePath: String? {
        guard let dict = parsedInput,
              let path = dict["file_path"] as? String,
              !path.isEmpty else { return nil }
        return path
    }

    /// The last path component of `filePath`.
    public var fileName: String? {
        guard let path = filePath else { return nil }
        return (path as NSString).lastPathComponent
    }
}
