import Foundation

public struct ToolUseEvent: Sendable, Codable, Identifiable {
    public enum Status: String, Sendable, Codable {
        case running
        case completed
    }

    public let id: String
    public var name: String
    public var inputJSON: String
    public var status: Status
    public var resultOutput: String
    public var cachedInputSummary: String
    public var cachedResultSummary: String

    public init(
        id: String,
        name: String,
        inputJSON: String = "",
        status: Status = .running,
        resultOutput: String = "",
        cachedInputSummary: String = "",
        cachedResultSummary: String = ""
    ) {
        self.id = id
        self.name = name
        self.inputJSON = inputJSON
        self.status = status
        self.resultOutput = resultOutput
        self.cachedInputSummary = cachedInputSummary
        self.cachedResultSummary = cachedResultSummary
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

    /// Parses `inputJSON` into a dictionary. Shared by `inputSummary` and `filePath`.
    private var parsedInput: [String: Any]? {
        guard let data = inputJSON.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    public var inputSummary: String {
        if !cachedInputSummary.isEmpty { return cachedInputSummary }
        guard let dict = parsedInput else { return "" }

        let value: String? = switch name {
        case "Read", "Write", "Edit":
            dict["file_path"] as? String
        case "Bash":
            dict["command"] as? String
        case "Glob":
            dict["pattern"] as? String
        case "Grep":
            dict["pattern"] as? String
        default:
            dict.values.first.flatMap { $0 as? String }
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
        if let dict = parsedInput,
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

    // MARK: - Display metadata

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
        case "Glob": "magnifyingglass"
        case "Grep": "text.magnifyingglass"
        case "WebFetch", "WebSearch": "globe"
        case "Agent": "person.2"
        default: "wrench"
        }
    }
}
