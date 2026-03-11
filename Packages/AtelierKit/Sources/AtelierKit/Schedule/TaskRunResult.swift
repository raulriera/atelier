import Foundation

/// Structured result from a scheduled task execution.
///
/// Parsed from the JSON log written by `claude -p --output-format json`.
/// Contains both user-facing summaries and raw diagnostic data for the AI.
public struct TaskRunResult: Sendable, Codable {
    /// When the task ran.
    public var date: Date
    /// Whether the CLI process reported success.
    public var succeeded: Bool
    /// Number of conversation turns the task used.
    public var numTurns: Int
    /// The model's final result text.
    public var resultText: String
    /// Tool names that were denied during execution.
    public var permissionDenials: [String]
    /// How long the task took in milliseconds.
    public var durationMs: Int
    /// Derived health assessment.
    public var health: Health

    public init(
        date: Date,
        succeeded: Bool,
        numTurns: Int,
        resultText: String,
        permissionDenials: [String],
        durationMs: Int,
        health: Health,
        userSummary: String,
        userDetail: String? = nil
    ) {
        self.date = date
        self.succeeded = succeeded
        self.numTurns = numTurns
        self.resultText = resultText
        self.permissionDenials = permissionDenials
        self.durationMs = durationMs
        self.health = health
        self.userSummary = userSummary
        self.userDetail = userDetail
    }

    /// Health status for the task run.
    public enum Health: String, Sendable, Codable {
        /// Task completed and used tools as expected.
        case healthy
        /// Task completed but something was off (no tools used, or denials).
        case warning
        /// Task encountered an error.
        case failed

        /// SF Symbol name for this health status.
        public var iconName: String {
            switch self {
            case .healthy: "checkmark.arrow.trianglehead.counterclockwise"
            case .warning, .failed: "exclamationmark.arrow.trianglehead.counterclockwise.rotate.90"
            }
        }

    }

    /// Plain-english summary shown to the user in the timeline.
    public var userSummary: String

    /// Plain-english detail shown when the user taps to expand.
    public var userDetail: String?

    /// Parses a task log file into a structured result.
    ///
    /// The log may contain stderr mixed with the JSON result from
    /// `claude -p --output-format json`. We scan backwards for the
    /// last line that parses as a JSON object with a `"result"` key.
    /// Returns `nil` if the log is missing or no valid result line is found.
    public static func parse(logURL: URL) -> TaskRunResult? {
        guard let raw = try? String(contentsOf: logURL, encoding: .utf8),
              !raw.isEmpty else {
            return nil
        }

        // Try the whole file first (fast path for clean logs).
        // Fall back to scanning lines in reverse for the result object.
        let json: [String: Any]
        if let data = raw.data(using: .utf8),
           let whole = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           whole["result"] != nil {
            json = whole
        } else {
            let lines = raw.components(separatedBy: .newlines)
            guard let found = lines.last(where: { line in
                guard let lineData = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      obj["result"] != nil else { return false }
                return true
            }),
            let foundData = found.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: foundData) as? [String: Any] else {
                return nil
            }
            json = parsed
        }

        let isError = json["is_error"] as? Bool ?? true
        let subtype = json["subtype"] as? String ?? ""
        let numTurns = json["num_turns"] as? Int ?? 0
        let resultText = json["result"] as? String ?? ""
        let durationMs = json["duration_ms"] as? Int ?? 0

        // Extract permission denial tool names
        let denials: [String]
        if let denialArray = json["permission_denials"] as? [[String: Any]] {
            denials = denialArray.compactMap { $0["tool_name"] as? String }
        } else {
            denials = []
        }

        // Determine health
        let health: Health
        if isError || subtype == "error" {
            health = .failed
        } else if !denials.isEmpty || numTurns <= 1 {
            health = .warning
        } else {
            health = .healthy
        }

        // Build user-facing summary
        let userSummary: String
        let userDetail: String?

        switch health {
        case .healthy:
            userSummary = "completed successfully"
            userDetail = nil

        case .warning:
            userSummary = "completed, but wasn't able to do everything it needed"
            if !denials.isEmpty {
                let toolNames = denials.map { friendlyToolName($0) }
                let joined = toolNames.formatted(.list(type: .and))
                userDetail = "The task finished but was blocked from using \(joined). You may need to adjust the task's permissions or prompt."
            } else {
                userDetail = "The task finished without taking any actions. The prompt may need to be more specific."
            }

        case .failed:
            userSummary = "ran into a problem"
            userDetail = "Something went wrong while running this task. Try running it again, or ask for help diagnosing the issue."
        }

        return TaskRunResult(
            date: Date(),
            succeeded: !isError,
            numTurns: numTurns,
            resultText: resultText,
            permissionDenials: denials,
            durationMs: durationMs,
            health: health,
            userSummary: userSummary,
            userDetail: userDetail
        )
    }

    /// Converts an MCP tool identifier to a user-friendly name.
    private static func friendlyToolName(_ tool: String) -> String {
        // "mcp__atelier-mail__mail_send_message" → "sending email"
        let mappings: [(String, String)] = [
            ("mail_send_message", "sending email"),
            ("mail_create_draft", "creating email drafts"),
            ("mail_search_messages", "searching email"),
            ("mail_get_message", "reading email"),
            ("calendar_", "accessing your calendar"),
            ("reminders_", "accessing your reminders"),
            ("notes_", "accessing your notes"),
            ("safari_", "browsing the web"),
        ]

        let lowered = tool.lowercased()
        for (pattern, friendly) in mappings {
            if lowered.contains(pattern) { return friendly }
        }

        // Fallback: strip MCP prefix and humanize
        let stripped = tool
            .replacingOccurrences(of: "mcp__atelier-", with: "")
            .replacingOccurrences(of: "mcp__", with: "")
            .replacingOccurrences(of: "__", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return stripped
    }
}
