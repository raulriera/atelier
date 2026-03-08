import Testing
import Foundation
@testable import AtelierKit

/// A mock CLI runner that always throws.
private struct FailingCLIRunner: CLIRunner {
    func run(arguments: [String], workingDirectory: URL) async throws -> String {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "CLI unavailable"])
    }
}

@Suite("ProjectFingerprinter")
struct ProjectFingerprinterTests {

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectFingerprinterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func createFile(_ name: String, in dir: URL, content: String = "") throws {
        let url = dir.appendingPathComponent(name)
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Scan

    @Test("Scans an empty directory and returns zero files")
    func scanEmptyDirectory() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.totalFiles == 0)
        #expect(fingerprint.categories.isEmpty)
    }

    @Test("Categorizes spreadsheet files")
    func categorizeSpreadsheets() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("q1-revenue.csv", in: dir)
        try createFile("q2-revenue.xlsx", in: dir)
        try createFile("q3-revenue.tsv", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.totalFiles == 3)

        let spreadsheets = try #require(fingerprint.categories.first { $0.name == "Spreadsheets" })
        #expect(spreadsheets.count == 3)
    }

    @Test("Categorizes document files")
    func categorizeDocuments() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("report.pdf", in: dir)
        try createFile("notes.txt", in: dir)
        try createFile("proposal.docx", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.totalFiles == 3)

        let documents = try #require(fingerprint.categories.first { $0.name == "Documents" })
        #expect(documents.count == 3)
    }

    @Test("Categorizes source code files")
    func categorizeSourceCode() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("Sources/main.swift", in: dir)
        try createFile("Sources/model.swift", in: dir)
        try createFile("Package.swift", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.totalFiles == 3)

        let code = try #require(fingerprint.categories.first { $0.name == "Source code" })
        #expect(code.count == 3)
    }

    @Test("Builds folder structure from nested files")
    func buildStructure() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("src/a.swift", in: dir)
        try createFile("src/b.swift", in: dir)
        try createFile("tests/c.swift", in: dir)
        try createFile("root.txt", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.structure.count == 2)

        let src = try #require(fingerprint.structure.first { $0.name == "src" })
        #expect(src.fileCount == 2)

        let tests = try #require(fingerprint.structure.first { $0.name == "tests" })
        #expect(tests.fileCount == 1)
    }

    @Test("Finds key files at the project root")
    func findKeyFiles() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("Package.swift", in: dir)
        try createFile("README.md", in: dir)
        try createFile("src/helper.swift", in: dir)
        try createFile("random.txt", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.keyFiles.contains("Package.swift"))
        #expect(fingerprint.keyFiles.contains("README.md"))
        #expect(!fingerprint.keyFiles.contains("random.txt"))
    }

    @Test("Scan includes raw file list")
    func scanIncludesFileList() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("a.csv", in: dir)
        try createFile("sub/b.txt", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.files.contains("a.csv"))
        #expect(fingerprint.files.contains("sub/b.txt"))
    }

    // MARK: - Render (heuristic fallback)

    @Test("Renders a readable summary for a code project")
    func renderCodeProject() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("Package.swift", in: dir)
        try createFile("Sources/App.swift", in: dir)
        try createFile("Sources/Model.swift", in: dir)
        try createFile("Tests/AppTests.swift", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        let output = ProjectFingerprinter.render(fingerprint)

        #expect(output.contains("# Project Context"))
        #expect(output.contains("Source code"))
        #expect(output.contains("Sources/"))
    }

    @Test("Renders a readable summary for a document folder")
    func renderDocumentFolder() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("report-q1.pdf", in: dir)
        try createFile("report-q2.pdf", in: dir)
        try createFile("notes.txt", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        let output = ProjectFingerprinter.render(fingerprint)

        #expect(output.contains("# Project Context"))
        #expect(output.contains("Documents"))
    }

    // MARK: - Summarize (Haiku)

    @Test("Summarize uses Haiku response when available")
    func summarizeUsesHaiku() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("data.csv", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        let runner = MockCLIRunner(output: "# Project Context\n\nA collection of financial data.")
        let output = await ProjectFingerprinter.summarize(fingerprint, runner: runner, workingDirectory: dir)

        #expect(output.contains("# Project Context"))
        #expect(output.contains("financial data"))
    }

    @Test("Summarize prepends heading when Haiku omits it")
    func summarizePrependsHeading() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("data.csv", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        let runner = MockCLIRunner(output: "A collection of quarterly reports.")
        let output = await ProjectFingerprinter.summarize(fingerprint, runner: runner, workingDirectory: dir)

        #expect(output.hasPrefix("# Project Context"))
        #expect(output.contains("quarterly reports"))
    }

    @Test("Summarize falls back to heuristic when CLI fails")
    func summarizeFallsBackOnFailure() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("data.csv", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        let runner = FailingCLIRunner()
        let output = await ProjectFingerprinter.summarize(fingerprint, runner: runner, workingDirectory: dir)

        // Falls back to heuristic render
        #expect(output.contains("# Project Context"))
        #expect(output.contains("Spreadsheets"))
    }

    @Test("Summarize falls back when Haiku returns empty string")
    func summarizeFallsBackOnEmpty() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("data.csv", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        let runner = MockCLIRunner(output: "")
        let output = await ProjectFingerprinter.summarize(fingerprint, runner: runner, workingDirectory: dir)

        #expect(output.contains("# Project Context"))
        #expect(output.contains("Spreadsheets"))
    }

    // MARK: - Generate if missing

    @Test("Generates context.md with heuristic when no runner provided")
    func generateWithoutRunner() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("data.csv", in: dir)
        try createFile("data2.csv", in: dir)

        let created = await ProjectFingerprinter.generateIfMissing(at: dir)
        #expect(created)

        let contextPath = dir
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("context.md")
        #expect(FileManager.default.fileExists(atPath: contextPath.path))

        let content = try String(contentsOf: contextPath, encoding: .utf8)
        #expect(content.contains("# Project Context"))
        #expect(content.contains("Spreadsheets"))
    }

    @Test("Generates context.md with Haiku when runner provided")
    func generateWithRunner() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("data.csv", in: dir)

        let runner = MockCLIRunner(output: "# Project Context\n\nA data analysis project.")
        let created = await ProjectFingerprinter.generateIfMissing(at: dir, runner: runner)
        #expect(created)

        let contextPath = dir
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("context.md")
        let content = try String(contentsOf: contextPath, encoding: .utf8)
        #expect(content.contains("data analysis"))
    }

    @Test("Does not overwrite existing context.md")
    func doesNotOverwriteExisting() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let contextPath = dir
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("context.md")
        try FileManager.default.createDirectory(
            at: contextPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "Custom context".write(to: contextPath, atomically: true, encoding: .utf8)

        let created = await ProjectFingerprinter.generateIfMissing(at: dir)
        #expect(!created)

        let content = try String(contentsOf: contextPath, encoding: .utf8)
        #expect(content == "Custom context")
    }

    @Test("Does not generate for empty directories")
    func doesNotGenerateForEmpty() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let created = await ProjectFingerprinter.generateIfMissing(at: dir)
        #expect(!created)
    }

    // MARK: - Prompt construction

    @Test("Prompt includes folder structure and categories")
    func promptIncludesStructure() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("src/main.swift", in: dir)
        try createFile("src/model.swift", in: dir)
        try createFile("docs/readme.txt", in: dir)
        try createFile("Package.swift", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        let prompt = ProjectFingerprinter.buildPrompt(fingerprint)

        #expect(prompt.contains("src/"))
        #expect(prompt.contains("docs/"))
        #expect(prompt.contains("Source code"))
        #expect(prompt.contains("Package.swift"))
    }

    // MARK: - Mixed content

    @Test("Handles a folder with mixed content types")
    func mixedContentTypes() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("budget.xlsx", in: dir)
        try createFile("report.pdf", in: dir)
        try createFile("photo.jpg", in: dir)
        try createFile("script.py", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.totalFiles == 4)
        #expect(fingerprint.categories.count == 4)

        let output = ProjectFingerprinter.render(fingerprint)
        #expect(output.contains("# Project Context"))
    }

    @Test("Categories are sorted by count descending")
    func categoriesSortedByCount() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try createFile("a.csv", in: dir)
        try createFile("b.csv", in: dir)
        try createFile("c.csv", in: dir)
        try createFile("d.pdf", in: dir)

        let fingerprint = ProjectFingerprinter.scan(at: dir)
        #expect(fingerprint.categories.first?.name == "Spreadsheets")
        #expect(fingerprint.categories.last?.name == "Documents")
    }
}
