import Testing
import Foundation
@testable import AtelierKit

@Suite("TaskRunResult")
struct TaskRunResultTests {

    // MARK: - Log Parsing

    @Test("parses successful log with tools used")
    func parsesHealthyResult() throws {
        let log = makeLog(isError: false, numTurns: 3, result: "Done! Created the report.", permissionDenials: [])
        let url = try writeTempLog(log)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try #require(TaskRunResult.parse(logURL: url))
        #expect(result.succeeded == true)
        #expect(result.numTurns == 3)
        #expect(result.health == .healthy)
        #expect(result.permissionDenials.isEmpty)
        #expect(result.userSummary.contains("successfully"))
        #expect(result.userDetail == nil)
    }

    @Test("parses warning when permission denied")
    func parsesPermissionDenial() throws {
        let log = makeLog(
            isError: false,
            numTurns: 2,
            result: "I tried to send email but was blocked.",
            permissionDenials: [["tool_name": "mcp__atelier-mail__mail_send_message"]]
        )
        let url = try writeTempLog(log)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try #require(TaskRunResult.parse(logURL: url))
        #expect(result.health == .warning)
        #expect(result.permissionDenials == ["mcp__atelier-mail__mail_send_message"])
        #expect(result.userDetail?.contains("sending email") == true)
    }

    @Test("parses warning when only one turn and no tools")
    func parsesNoToolsWarning() throws {
        let log = makeLog(isError: false, numTurns: 1, result: "I need more info.", permissionDenials: [])
        let url = try writeTempLog(log)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try #require(TaskRunResult.parse(logURL: url))
        #expect(result.health == .warning)
        #expect(result.userDetail?.contains("without taking any actions") == true)
    }

    @Test("parses failed result")
    func parsesFailedResult() throws {
        let log = makeLog(isError: true, numTurns: 0, result: "Error occurred", permissionDenials: [])
        let url = try writeTempLog(log)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try #require(TaskRunResult.parse(logURL: url))
        #expect(result.health == .failed)
        #expect(result.succeeded == false)
        #expect(result.userSummary.contains("problem"))
    }

    @Test("returns nil for missing log file")
    func returnsNilForMissingLog() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID()).log")
        #expect(TaskRunResult.parse(logURL: url) == nil)
    }

    @Test("returns nil for empty log file")
    func returnsNilForEmptyLog() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("empty-\(UUID()).log")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(TaskRunResult.parse(logURL: url) == nil)
    }

    @Test("returns nil for invalid JSON")
    func returnsNilForBadJSON() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bad-\(UUID()).log")
        try "not json".data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(TaskRunResult.parse(logURL: url) == nil)
    }

    // MARK: - Mixed Log Content

    @Test("parses result from log with stderr mixed in")
    func parsesMixedLog() throws {
        let jsonLine = try JSONSerialization.data(
            withJSONObject: makeLog(isError: false, numTurns: 4, result: "Report ready.", permissionDenials: [])
        )
        let mixed = """
        [INFO] Starting task...
        Some stderr diagnostic output
        \(String(data: jsonLine, encoding: .utf8)!)
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mixed-\(UUID()).log")
        try mixed.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try #require(TaskRunResult.parse(logURL: url))
        #expect(result.succeeded == true)
        #expect(result.numTurns == 4)
        #expect(result.health == .healthy)
        #expect(result.resultText == "Report ready.")
    }

    // MARK: - Codable Round-Trip

    @Test("round-trips through JSON encoding")
    func codableRoundTrip() throws {
        let original = TaskRunResult(
            date: Date(),
            succeeded: true,
            numTurns: 3,
            resultText: "All done",
            permissionDenials: ["mcp__atelier-mail__mail_send_message"],
            durationMs: 5000,
            health: .warning,
            userSummary: "completed, but wasn't able to do everything it needed",
            userDetail: "Blocked from sending email."
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskRunResult.self, from: data)
        #expect(decoded.succeeded == original.succeeded)
        #expect(decoded.health == original.health)
        #expect(decoded.permissionDenials == original.permissionDenials)
        #expect(decoded.userSummary == original.userSummary)
        #expect(decoded.userDetail == original.userDetail)
    }

    // MARK: - Helpers

    private func makeLog(
        isError: Bool,
        numTurns: Int,
        result: String,
        permissionDenials: [[String: String]]
    ) -> [String: Any] {
        [
            "type": "result",
            "subtype": isError ? "error" : "success",
            "is_error": isError,
            "num_turns": numTurns,
            "result": result,
            "duration_ms": 5000,
            "permission_denials": permissionDenials,
        ]
    }

    private func writeTempLog(_ json: [String: Any]) throws -> URL {
        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("task-test-\(UUID()).log")
        try data.write(to: url)
        return url
    }
}
