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

    public init(id: String, name: String, inputJSON: String = "", status: Status = .running) {
        self.id = id
        self.name = name
        self.inputJSON = inputJSON
        self.status = status
    }

    public var inputSummary: String {
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
