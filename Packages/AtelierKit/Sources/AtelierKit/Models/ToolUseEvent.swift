import Foundation

public struct ToolUseEvent: Sendable, Codable, Identifiable {
    public enum Status: String, Sendable, Codable {
        case running
        case completed
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, inputJSON, status, resultOutput, cachedInputSummary, cachedResultSummary, cachedPlainDescription
    }

    public let id: String
    public var name: String
    public var inputJSON: String
    public var status: Status
    public var resultOutput: String
    public var cachedInputSummary: String
    public var cachedResultSummary: String
    public var cachedPlainDescription: String

    // Cached derived properties — excluded from Codable, recomputed via cacheInputProperties().
    private struct CachedInput: Sendable {
        var filePath: String?
        var inputSummaryValue: String?
        var editOldString: String?
        var editNewString: String?
        var taskSubject: String?
        var taskStatus: String?
        var taskId: String?
    }
    private var _cached: CachedInput?

    public init(
        id: String,
        name: String,
        inputJSON: String = "",
        status: Status = .running,
        resultOutput: String = "",
        cachedInputSummary: String = "",
        cachedResultSummary: String = "",
        cachedPlainDescription: String = ""
    ) {
        self.id = id
        self.name = name
        self.inputJSON = inputJSON
        self.status = status
        self.resultOutput = resultOutput
        self.cachedInputSummary = cachedInputSummary
        self.cachedResultSummary = cachedResultSummary
        self.cachedPlainDescription = cachedPlainDescription
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        inputJSON = try container.decode(String.self, forKey: .inputJSON)
        status = try container.decode(Status.self, forKey: .status)
        resultOutput = try container.decodeIfPresent(String.self, forKey: .resultOutput) ?? ""
        cachedInputSummary = try container.decodeIfPresent(String.self, forKey: .cachedInputSummary) ?? ""
        cachedResultSummary = try container.decodeIfPresent(String.self, forKey: .cachedResultSummary) ?? ""
        cachedPlainDescription = try container.decodeIfPresent(String.self, forKey: .cachedPlainDescription) ?? ""
    }

    /// Extracts the primary input value from a parsed JSON dictionary based on tool name.
    private static func summaryValue(for name: String, from dict: [String: Any]) -> String? {
        switch name {
        case "Read", "Write", "Edit": dict["file_path"] as? String
        case "Bash": dict["command"] as? String
        case "Glob": dict["pattern"] as? String
        case "Grep": dict["pattern"] as? String
        default: dict.values.first.flatMap { $0 as? String }
        }
    }

    /// Parses `inputJSON` once and stores derived values for fast access from view bodies.
    /// Call this after inputJSON is finalized (tool completion, payload population, restore).
    public mutating func cacheInputProperties() {
        guard let data = inputJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            _cached = CachedInput()
            return
        }

        let isTask = Self.taskToolNames.contains(name)

        _cached = CachedInput(
            filePath: dict["file_path"] as? String,
            inputSummaryValue: Self.summaryValue(for: name, from: dict),
            editOldString: (name == "Edit") ? dict["old_string"] as? String : nil,
            editNewString: (name == "Edit") ? dict["new_string"] as? String : nil,
            taskSubject: isTask ? dict["subject"] as? String : nil,
            taskStatus: isTask ? dict["status"] as? String : nil,
            taskId: isTask ? dict["taskId"] as? String : nil
        )
    }

    /// Whether this tool has result output available — either loaded or cached in the sidecar.
    public var hasResultOutput: Bool {
        !resultOutput.isEmpty || !cachedResultSummary.isEmpty
    }

    public var resultSummary: String {
        if !cachedResultSummary.isEmpty { return cachedResultSummary }
        guard !resultOutput.isEmpty else { return "" }

        // Scan for the first 3 lines without splitting the entire string.
        var lineCount = 0
        var endIndex = resultOutput.startIndex
        while endIndex < resultOutput.endIndex && lineCount < 3 {
            if resultOutput[endIndex] == "\n" { lineCount += 1 }
            endIndex = resultOutput.index(after: endIndex)
        }
        // Trim trailing newline from the third line boundary
        if endIndex > resultOutput.startIndex && resultOutput[resultOutput.index(before: endIndex)] == "\n" {
            endIndex = resultOutput.index(before: endIndex)
        }
        let joined = String(resultOutput[..<endIndex])
        if joined.count <= 120 { return joined }
        return String(joined.prefix(117)) + "..."
    }

    /// Parses `inputJSON` into a dictionary. Only used as fallback when cache isn't populated.
    private var parsedInput: [String: Any]? {
        guard let data = inputJSON.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    public var inputSummary: String {
        if !cachedInputSummary.isEmpty { return cachedInputSummary }

        let value: String?
        if let cached = _cached {
            value = cached.inputSummaryValue
        } else {
            guard let dict = parsedInput else { return "" }
            value = Self.summaryValue(for: name, from: dict)
        }

        guard let value, !value.isEmpty else { return "" }
        if value.count <= 80 { return value }
        return String(value.prefix(77)) + "..."
    }

    // MARK: - File operations

    /// Whether this tool is a file operation (Read, Write, or Edit).
    public var isFileOperation: Bool {
        switch name {
        case "Read", "Write", "Edit": true
        default: false
        }
    }

    /// The file path extracted from `inputJSON`, falling back to `cachedInputSummary`.
    public var filePath: String? {
        if let cached = _cached {
            if let path = cached.filePath, !path.isEmpty { return path }
        } else if let dict = parsedInput,
                  let path = dict["file_path"] as? String,
                  !path.isEmpty {
            return path
        }
        let summary = cachedInputSummary
        if !summary.isEmpty && summary.hasPrefix("/") {
            return summary
        }
        return nil
    }

    /// The last path component of `filePath`.
    public var fileName: String? {
        guard let path = filePath else { return nil }
        return (path as NSString).lastPathComponent
    }

    /// The parent directory of `filePath`, with the home directory abbreviated to `~`.
    public var fileDirectory: String? {
        guard let path = filePath else { return nil }
        let dir = (path as NSString).deletingLastPathComponent
        guard !dir.isEmpty else { return nil }
        let home = NSHomeDirectory()
        if dir.hasPrefix(home) {
            return "~" + dir.dropFirst(home.count)
        }
        return dir
    }

    /// The detected file type based on the file extension.
    public var fileType: FileType {
        guard let name = fileName else { return .unknown }
        return FileType(fileName: name)
    }

    /// The file content with `cat -n` line number prefixes stripped.
    ///
    /// The CLI returns file content in `cat -n` format (e.g. `     1→import SwiftUI`).
    /// This property strips those prefixes so the content can be rendered as-is.
    public var fileContent: String {
        let raw = resultOutput.isEmpty ? cachedResultSummary : resultOutput
        guard !raw.isEmpty else { return "" }
        // Fast path: no arrow character means no cat -n prefixes to strip.
        guard raw.contains("\u{2192}") else { return raw }
        return raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                if let arrowIndex = line.firstIndex(of: "\u{2192}") {
                    let prefix = line[..<arrowIndex]
                    if prefix.allSatisfy({ $0.isWhitespace || $0.isNumber }) {
                        return String(line[line.index(after: arrowIndex)...])
                    }
                }
                return String(line)
            }
            .joined(separator: "\n")
    }

    // MARK: - Edit operations

    /// The original text from an Edit tool's `old_string` parameter.
    public var editOldString: String? {
        guard name == "Edit" else { return nil }
        if let cached = _cached { return cached.editOldString }
        return parsedInput?["old_string"] as? String
    }

    /// The replacement text from an Edit tool's `new_string` parameter.
    public var editNewString: String? {
        guard name == "Edit" else { return nil }
        if let cached = _cached { return cached.editNewString }
        return parsedInput?["new_string"] as? String
    }

    // MARK: - Ask-user operations

    private static let askUserToolNames: Set<String> = [
        "mcp__atelier__ask_user",
        "AskUserQuestion",
    ]

    /// Whether this tool is an ask-user operation rendered by AskUserCard.
    public var isAskUserOperation: Bool {
        Self.askUserToolNames.contains(name)
    }

    // MARK: - Task operations

    private static let taskToolNames: Set<String> = [
        "Task", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet",
        "TodoWrite", "TodoRead",
    ]

    /// Whether this tool is a task operation.
    public var isTaskOperation: Bool {
        Self.taskToolNames.contains(name)
    }

    /// The task subject extracted from `inputJSON`.
    public var taskSubject: String? {
        guard isTaskOperation else { return nil }
        if let cached = _cached { return cached.taskSubject }
        return parsedInput?["subject"] as? String
    }

    /// The task status extracted from `inputJSON` (TaskUpdate's `status` field).
    public var taskStatus: String? {
        guard isTaskOperation else { return nil }
        if let cached = _cached { return cached.taskStatus }
        return parsedInput?["status"] as? String
    }

    /// The task ID extracted from `inputJSON` (TaskUpdate/TaskGet's `taskId` field).
    public var taskId: String? {
        guard isTaskOperation else { return nil }
        if let cached = _cached { return cached.taskId }
        return parsedInput?["taskId"] as? String
    }

    /// Parsed todo items from a `TodoWrite` event, cached after first access.
    ///
    /// TodoWrite sends the full list each time:
    /// `{"todos": [{"id":"1","content":"...","status":"in_progress"}, ...]}`
    public var todoItems: [TodoItem]? {
        guard name == "TodoWrite" else { return nil }
        guard let dict = parsedInput,
              let todos = dict["todos"] as? [[String: Any]] else { return nil }
        return todos.compactMap { TodoItem(dict: $0) }
    }

    // MARK: - Display metadata

    /// A human-readable sentence describing what this tool call does.
    ///
    /// Survives payload stripping via `cachedPlainDescription`, which is precomputed
    /// in `separatePayloads` before `inputJSON` is cleared.
    public var plainDescription: String {
        if !cachedPlainDescription.isEmpty { return cachedPlainDescription }

        switch name {
        case "Bash":
            if let desc = parsedInput?["description"] as? String, !desc.isEmpty { return desc }
            return "Run a terminal command"

        case "Read":
            if let file = fileName { return "Reading \(file)" }
            return "Reading a file"

        case "Write":
            if let file = fileName { return "Creating \(file)" }
            return "Creating a new file"

        case "Edit":
            if let file = fileName { return "Editing \(file)" }
            return "Editing a file"

        case "Glob":
            if let pattern = _cached?.inputSummaryValue ?? (parsedInput?["pattern"] as? String) {
                return "Searching for files matching \(pattern)"
            }
            return "Searching for files"

        case "Grep":
            if let pattern = _cached?.inputSummaryValue ?? (parsedInput?["pattern"] as? String) {
                return "Searching file contents for \"\(pattern)\""
            }
            return "Searching file contents"

        case "WebSearch":
            if let query = parsedInput?["query"] as? String {
                return "Searching the web for \"\(query)\""
            }
            return "Searching the web"

        case "WebFetch":
            if let url = parsedInput?["url"] as? String,
               let host = URL(string: url)?.host {
                return "Fetching a page from \(host)"
            }
            return "Fetching a web page"

        case "Agent":
            if let desc = parsedInput?["description"] as? String, !desc.isEmpty {
                let truncated = desc.count <= 60 ? desc : String(desc.prefix(57)) + "..."
                return truncated
            }
            return "Working on a subtask"

        case "Skill":
            if let skill = parsedInput?["skill"] as? String, !skill.isEmpty {
                return "Running \(skill)"
            }
            return "Running a skill"

        case "EnterPlanMode":
            return "Starting to plan"

        case "ExitPlanMode":
            return "Finished planning"

        case "ToolSearch":
            return "Searching for tools"

        case "TaskStop":
            return "Stopping a task"

        case "TaskOutput":
            return "Reading task output"

        default:
            if name.hasPrefix("mcp__") {
                let parts = name.split(separator: "__")
                if parts.count >= 3 {
                    let toolName = parts.last!.replacingOccurrences(of: "_", with: " ")
                    return toolName.capitalized
                }
            }
            return displayName
        }
    }

    /// User-friendly display name for the tool.
    public var displayName: String {
        switch name {
        case "Bash": "Terminal Command"
        case "Read": "Read File"
        case "Write": "Write File"
        case "Edit": "Edit File"
        case "Glob": "Search Files"
        case "Grep": "Search Content"
        case "WebFetch": "Fetch Web Page"
        case "WebSearch": "Web Search"
        case "Agent": "Sub-agent"
        case "Task", "TaskCreate", "TodoWrite": "Tasks"
        case "TaskUpdate": "Update Task"
        case "TaskList", "TodoRead": "Tasks"
        case "TaskGet": "Get Task"
        case "TaskOutput": "Task Output"
        case "TaskStop": "Stop Task"
        case "EnterPlanMode": "Planning"
        case "ExitPlanMode": "Planning"
        case "Skill": "Run Skill"
        case "ToolSearch": "Search Tools"
        default: name
        }
    }

    /// SF Symbol name for the tool.
    public var iconName: String {
        switch name {
        case "Read": "doc.text"
        case "Write": "doc.badge.plus"
        case "Edit": "pencil"
        case "Bash": "terminal"
        case "Glob", "ToolSearch": "magnifyingglass"
        case "Grep": "text.magnifyingglass"
        case "WebFetch", "WebSearch": "globe"
        case "Agent": "person.2"
        case "Task", "TaskCreate", "TodoWrite": "checklist"
        case "TaskUpdate": "checklist.checked"
        case "TaskList", "TaskGet", "TodoRead": "list.bullet"
        case "TaskOutput": "text.page"
        case "TaskStop": "stop.circle"
        case "EnterPlanMode": "checklist"
        case "ExitPlanMode": "checklist.checked"
        case "Skill": "wand.and.sparkles"
        default:
            if name.hasPrefix("mcp__") { "puzzlepiece.extension" }
            else { "sparkles.2" }
        }
    }
}
