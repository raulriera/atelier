import Testing
import Foundation
@testable import AtelierKit

@Suite("ToolUseEvent")
struct ToolUseEventTests {

    @Suite("isFileOperation")
    struct IsFileOperation {
        @Test("Read, Write, Edit are file operations", arguments: ["Read", "Write", "Edit"])
        func fileTools(name: String) {
            let event = ToolUseEvent(id: "t", name: name)
            #expect(event.isFileOperation)
        }

        @Test("Bash, Grep, Glob are not file operations", arguments: ["Bash", "Grep", "Glob"])
        func nonFileTools(name: String) {
            let event = ToolUseEvent(id: "t", name: name)
            #expect(!event.isFileOperation)
        }
    }

    @Suite("filePath")
    struct FilePath {
        @Test("Parses file_path from inputJSON")
        func parsesFromInputJSON() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                inputJSON: #"{"file_path":"/Users/dev/src/main.swift"}"#
            )
            #expect(event.filePath == "/Users/dev/src/main.swift")
        }

        @Test("Falls back to cachedInputSummary when inputJSON is empty")
        func fallsBackToCachedSummary() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                inputJSON: "",
                cachedInputSummary: "/Users/dev/src/main.swift"
            )
            #expect(event.filePath == "/Users/dev/src/main.swift")
        }

        @Test("Returns nil for non-path cachedInputSummary")
        func returnsNilForNonPath() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                inputJSON: "",
                cachedInputSummary: "some summary"
            )
            #expect(event.filePath == nil)
        }

        @Test("Returns nil when both are empty")
        func returnsNilWhenEmpty() {
            let event = ToolUseEvent(id: "t", name: "Read")
            #expect(event.filePath == nil)
        }
    }

    @Suite("fileName")
    struct FileName {
        @Test("Extracts last path component")
        func extractsLastComponent() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                inputJSON: #"{"file_path":"/Users/dev/src/MarkdownRenderer.swift"}"#
            )
            #expect(event.fileName == "MarkdownRenderer.swift")
        }

        @Test("Returns nil when no filePath")
        func returnsNilWhenNoPath() {
            let event = ToolUseEvent(id: "t", name: "Read")
            #expect(event.fileName == nil)
        }
    }

    @Suite("fileDirectory")
    struct FileDirectory {
        @Test("Abbreviates home directory with ~")
        func abbreviatesHomeDirectory() {
            let home = NSHomeDirectory()
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                inputJSON: #"{"file_path":"\#(home)/Developer/project/file.swift"}"#
            )
            #expect(event.fileDirectory == "~/Developer/project")
        }

        @Test("Preserves non-home paths as-is")
        func preservesNonHomePaths() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                inputJSON: #"{"file_path":"/tmp/scratch/file.swift"}"#
            )
            #expect(event.fileDirectory == "/tmp/scratch")
        }

        @Test("Returns nil when no filePath")
        func returnsNilWhenNoPath() {
            let event = ToolUseEvent(id: "t", name: "Read")
            #expect(event.fileDirectory == nil)
        }
    }

    @Suite("displayName")
    struct DisplayName {
        @Test("Returns correct display names", arguments: [
            ("Bash", "Terminal Command"),
            ("Read", "Read File"),
            ("Write", "Write File"),
            ("Edit", "Edit File"),
            ("Glob", "Search Files"),
            ("Grep", "Search Content"),
            ("WebFetch", "Fetch Web Page"),
            ("WebSearch", "Web Search"),
            ("Agent", "Sub-agent"),
        ])
        func correctDisplayNames(input: (tool: String, expected: String)) {
            let event = ToolUseEvent(id: "t", name: input.tool)
            #expect(event.displayName == input.expected)
        }

        @Test("Unknown tool returns raw name")
        func unknownToolReturnsRawName() {
            let event = ToolUseEvent(id: "t", name: "CustomTool")
            #expect(event.displayName == "CustomTool")
        }
    }

    @Suite("iconName")
    struct IconName {
        @Test("Returns correct icon names", arguments: [
            ("Read", "doc.text"),
            ("Write", "doc.badge.plus"),
            ("Edit", "pencil"),
            ("Bash", "terminal"),
            ("Glob", "magnifyingglass"),
            ("Grep", "text.magnifyingglass"),
            ("WebFetch", "globe"),
            ("WebSearch", "globe"),
            ("Agent", "person.2"),
        ])
        func correctIconNames(input: (tool: String, expected: String)) {
            let event = ToolUseEvent(id: "t", name: input.tool)
            #expect(event.iconName == input.expected)
        }

        @Test("Unknown tool returns sparkles")
        func unknownToolReturnsSparkles() {
            let event = ToolUseEvent(id: "t", name: "CustomTool")
            #expect(event.iconName == "sparkles.2")
        }

        @Test("MCP tool returns puzzle piece")
        func mcpToolReturnsPuzzlePiece() {
            let event = ToolUseEvent(id: "t", name: "mcp__pencil__batch_design")
            #expect(event.iconName == "puzzlepiece.extension")
        }
    }

    @Suite("fileType")
    struct FileTypeTests {
        @Test("Markdown extensions detected", arguments: ["md", "markdown", "mdown", "mkd"])
        func markdownDetected(ext: String) {
            #expect(FileType(fileName: "notes.\(ext)") == .markdown)
        }

        @Test("Code extensions detected", arguments: [
            ("swift", "swift"), ("py", "python"), ("js", "javascript"),
            ("ts", "typescript"), ("rb", "ruby"), ("go", "go"),
        ])
        func codeDetected(input: (ext: String, language: String)) {
            #expect(FileType(fileName: "file.\(input.ext)") == .code(language: input.language))
        }

        @Test("Data extensions detected", arguments: [("json", "json"), ("csv", "csv")])
        func dataDetected(input: (ext: String, format: String)) {
            #expect(FileType(fileName: "file.\(input.ext)") == .data(format: input.format))
        }

        @Test("Plain text extensions detected", arguments: ["txt", "log"])
        func plainTextDetected(ext: String) {
            #expect(FileType(fileName: "file.\(ext)") == .plainText)
        }

        @Test("Unknown extension returns unknown")
        func unknownExtension() {
            #expect(FileType(fileName: "file.xyz") == .unknown)
        }

        @Test("No extension returns plain text")
        func noExtension() {
            #expect(FileType(fileName: "Makefile") == .plainText)
        }

        @Test("ToolUseEvent.fileType uses file name")
        func eventFileType() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                inputJSON: #"{"file_path":"/docs/report.md"}"#
            )
            #expect(event.fileType == .markdown)
        }
    }

    @Suite("isPlanReview")
    struct PlanReviewTests {
        @Test("Only ExitPlanMode is a plan review")
        func onlyExitIsPlanReview() {
            let exit = ToolUseEvent(id: "t", name: "ExitPlanMode")
            #expect(exit.isPlanReview)

            let enter = ToolUseEvent(id: "t", name: "EnterPlanMode")
            #expect(!enter.isPlanReview)

            let other = ToolUseEvent(id: "t", name: "Bash")
            #expect(!other.isPlanReview)
        }
    }

    @Suite("editOldString / editNewString")
    struct EditStrings {
        @Test("Parses old_string and new_string from Edit tool")
        func parsesEditStrings() {
            let event = ToolUseEvent(
                id: "t",
                name: "Edit",
                inputJSON: #"{"file_path":"/tmp/f.md","old_string":"hello","new_string":"world"}"#
            )
            #expect(event.editOldString == "hello")
            #expect(event.editNewString == "world")
        }

        @Test("Returns nil for non-Edit tools")
        func returnsNilForNonEdit() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                inputJSON: #"{"file_path":"/tmp/f.md","old_string":"hello","new_string":"world"}"#
            )
            #expect(event.editOldString == nil)
            #expect(event.editNewString == nil)
        }

        @Test("Returns nil when inputJSON has no old_string")
        func returnsNilWhenMissing() {
            let event = ToolUseEvent(
                id: "t",
                name: "Edit",
                inputJSON: #"{"file_path":"/tmp/f.md"}"#
            )
            #expect(event.editOldString == nil)
            #expect(event.editNewString == nil)
        }

        @Test("Returns nil when inputJSON is empty")
        func returnsNilWhenEmpty() {
            let event = ToolUseEvent(id: "t", name: "Edit")
            #expect(event.editOldString == nil)
            #expect(event.editNewString == nil)
        }
    }

    @Suite("fileContent")
    struct FileContent {
        @Test("Strips cat -n line number prefixes")
        func stripsLineNumbers() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                status: .completed,
                resultOutput: "     1→# Hello\n     2→\n     3→Some text"
            )
            #expect(event.fileContent == "# Hello\n\nSome text")
        }

        @Test("Preserves lines without arrow prefix")
        func preservesPlainLines() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                status: .completed,
                resultOutput: "plain text\nno arrows here"
            )
            #expect(event.fileContent == "plain text\nno arrows here")
        }

        @Test("Preserves arrows that are not line number prefixes")
        func preservesNonPrefixArrows() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                status: .completed,
                resultOutput: "     1→text with → arrow inside"
            )
            #expect(event.fileContent == "text with → arrow inside")
        }

        @Test("Returns empty string for empty output")
        func returnsEmptyForEmptyOutput() {
            let event = ToolUseEvent(id: "t", name: "Read")
            #expect(event.fileContent == "")
        }

        @Test("Falls back to cachedResultSummary")
        func fallsBackToCachedSummary() {
            let event = ToolUseEvent(
                id: "t",
                name: "Read",
                status: .completed,
                cachedResultSummary: "     1→# Cached"
            )
            #expect(event.fileContent == "# Cached")
        }
    }
}
