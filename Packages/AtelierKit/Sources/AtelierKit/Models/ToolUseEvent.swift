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
        let lines = resultOutput.split(separator: "\n", omittingEmptySubsequences: false).prefix(3)
        let joined = lines.joined(separator: "\n")
        if joined.count <= 120 { return joined }
        return String(joined.prefix(117)) + "..."
    }

    public var inputSummary: String {
        if !cachedInputSummary.isEmpty { return cachedInputSummary }
        guard let data = inputJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }

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
}
