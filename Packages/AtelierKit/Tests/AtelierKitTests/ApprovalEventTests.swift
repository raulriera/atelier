import Testing
import Foundation
@testable import AtelierKit

@Suite("ApprovalEvent")
struct ApprovalEventTests {

    @Suite("Display metadata")
    struct DisplayMetadata {
        @Test("Display name maps tool names to user-friendly descriptions")
        func displayName() {
            let bash = ApprovalEvent(id: "1", toolName: "Bash")
            #expect(bash.displayName == "Run Terminal Command")

            let write = ApprovalEvent(id: "2", toolName: "Write")
            #expect(write.displayName == "Write File")

            let edit = ApprovalEvent(id: "3", toolName: "Edit")
            #expect(edit.displayName == "Edit File")

            let notebook = ApprovalEvent(id: "4", toolName: "NotebookEdit")
            #expect(notebook.displayName == "Edit Notebook")

            let unknown = ApprovalEvent(id: "5", toolName: "CustomTool")
            #expect(unknown.displayName == "Use CustomTool")
        }

        @Test("Icon name maps tool names to SF Symbols")
        func iconName() {
            #expect(ApprovalEvent(id: "1", toolName: "Bash").iconName == "terminal")
            #expect(ApprovalEvent(id: "2", toolName: "Write").iconName == "doc.badge.plus")
            #expect(ApprovalEvent(id: "3", toolName: "Edit").iconName == "pencil")
            #expect(ApprovalEvent(id: "4", toolName: "NotebookEdit").iconName == "book")
            #expect(ApprovalEvent(id: "5", toolName: "Unknown").iconName == "wrench")
        }

        @Test("Input summary extracts file path for file operations")
        func inputSummaryFilePath() {
            let event = ApprovalEvent(
                id: "1", toolName: "Edit",
                inputJSON: "{\"file_path\":\"/src/main.swift\",\"old_string\":\"a\",\"new_string\":\"b\"}"
            )
            #expect(event.inputSummary == "/src/main.swift")
        }

        @Test("Input summary extracts command for Bash")
        func inputSummaryBash() {
            let event = ApprovalEvent(
                id: "1", toolName: "Bash",
                inputJSON: "{\"command\":\"swift build\"}"
            )
            #expect(event.inputSummary == "swift build")
        }

        @Test("Input summary truncates long values")
        func inputSummaryTruncates() {
            let longPath = String(repeating: "a", count: 100)
            let event = ApprovalEvent(
                id: "1", toolName: "Write",
                inputJSON: "{\"file_path\":\"\(longPath)\"}"
            )
            #expect(event.inputSummary.count <= 80)
            #expect(event.inputSummary.hasSuffix("..."))
        }

        @Test("Input summary returns empty for invalid JSON")
        func inputSummaryInvalidJSON() {
            let event = ApprovalEvent(id: "1", toolName: "Bash", inputJSON: "not json")
            #expect(event.inputSummary == "")
        }

        @Test("File path extraction")
        func filePath() {
            let event = ApprovalEvent(
                id: "1", toolName: "Write",
                inputJSON: "{\"file_path\":\"/Users/test/file.swift\"}"
            )
            #expect(event.filePath == "/Users/test/file.swift")
            #expect(event.fileName == "file.swift")
        }

        @Test("File path returns nil for non-file tools")
        func filePathNil() {
            let event = ApprovalEvent(
                id: "1", toolName: "Bash",
                inputJSON: "{\"command\":\"ls\"}"
            )
            #expect(event.filePath == nil)
            #expect(event.fileName == nil)
        }
    }

    @Suite("Codable")
    struct CodableTests {
        @Test("Roundtrip encoding and decoding")
        func codableRoundtrip() throws {
            let original = ApprovalEvent(
                id: "test-id",
                toolName: "Bash",
                inputJSON: "{\"command\":\"echo hello\"}",
                status: .approved,
                decidedAt: Date(timeIntervalSince1970: 1000)
            )

            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(ApprovalEvent.self, from: data)

            #expect(decoded.id == original.id)
            #expect(decoded.toolName == original.toolName)
            #expect(decoded.inputJSON == original.inputJSON)
            #expect(decoded.status == original.status)
            #expect(decoded.decidedAt == original.decidedAt)
        }

        @Test("Pending status encodes correctly")
        func pendingStatus() throws {
            let event = ApprovalEvent(id: "1", toolName: "Write")
            let data = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(ApprovalEvent.self, from: data)
            #expect(decoded.status == .pending)
            #expect(decoded.decidedAt == nil)
        }
    }
}
