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

    public static let exitPlanModeToolName = "ExitPlanMode"

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

        case "WebFetch":
            if let url = dict["url"] as? String,
               let host = URL(string: url)?.host {
                return "Reading a page from \(host)"
            }
            return "Read a webpage"

        case "WebSearch":
            if let query = dict["query"] as? String, !query.isEmpty {
                return "Searching the web for \"\(query)\""
            }
            return "Search the web"

        case "Read":
            if let path = dict["file_path"] as? String, !path.isEmpty {
                return "Read \((path as NSString).lastPathComponent)"
            }
            return "Read a file"

        case "Glob":
            if let pattern = dict["pattern"] as? String, !pattern.isEmpty {
                return "Search for files matching \(pattern)"
            }
            return "Search for files"

        case "Grep":
            if let pattern = dict["pattern"] as? String, !pattern.isEmpty {
                return "Search file contents for \"\(pattern)\""
            }
            return "Search file contents"

        case "Agent":
            if let desc = dict["description"] as? String, !desc.isEmpty {
                return desc.count <= 60 ? desc : String(desc.prefix(57)) + "..."
            }
            return "Work on a subtask"

        case "Skill":
            if let skill = dict["skill"] as? String, !skill.isEmpty {
                return "Run \(skill)"
            }
            return "Run a skill"

        case "ToolSearch":
            return "Search for tools"

        case "Task", "TaskCreate", "TodoWrite":
            return "Create a task"

        case "TaskUpdate":
            return "Update a task"

        case "TaskList", "TaskGet", "TodoRead":
            return "Check tasks"

        case "TaskOutput":
            return "Read task output"

        case "TaskStop":
            return "Stop a task"

        default:
            return MCPToolMetadata.displayName(for: toolName) ?? "Use \(toolName)"
        }
    }

    /// User-friendly display name describing what Claude wants to do.
    public var displayName: String {
        switch toolName {
        case "Bash": "Run Terminal Command"
        case "Write": "Write File"
        case "Edit": "Edit File"
        case "NotebookEdit": "Edit Notebook"
        case "WebFetch": "Read Webpage"
        case "WebSearch": "Web Search"
        case "Read": "Read File"
        case "Glob": "Search Files"
        case "Grep": "Search Content"
        case "Agent": "Sub-agent"
        case "Skill": "Run Skill"
        case "ToolSearch": "Search Tools"
        case "Task", "TaskCreate", "TodoWrite": "Tasks"
        case "TaskUpdate": "Update Task"
        case "TaskList", "TaskGet", "TodoRead": "Tasks"
        case "TaskOutput": "Task Output"
        case "TaskStop": "Stop Task"
        default: MCPToolMetadata.displayName(for: toolName) ?? "Use \(toolName)"
        }
    }

    /// SF Symbol name for the approval card.
    public var iconName: String {
        switch toolName {
        case "Write": "doc.badge.plus"
        case "Edit": "pencil"
        case "Bash": "terminal"
        case "NotebookEdit": "book"
        case "WebFetch", "WebSearch": "globe"
        case "Read": "doc.text"
        case "Glob", "ToolSearch": "magnifyingglass"
        case "Grep": "text.magnifyingglass"
        case "Agent": "person.2"
        case "Skill": "wand.and.sparkles"
        case "Task", "TaskCreate", "TodoWrite": "checklist"
        case "TaskUpdate": "checklist.checked"
        case "TaskList", "TaskGet", "TodoRead": "list.bullet"
        case "TaskOutput": "text.page"
        case "TaskStop": "stop.circle"
        default:
            if let mcpIcon = MCPToolMetadata.iconName(for: toolName) { mcpIcon }
            else if toolName.hasPrefix("mcp__") { "puzzlepiece.extension" }
            else { "wrench" }
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
