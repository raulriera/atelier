import Testing
import Foundation
@testable import AtelierKit

@Suite("ProjectDetector")
struct ProjectDetectorTests {

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectDetectorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Single-marker detection (parameterized)

    /// Describes a filesystem marker and the ``ProjectKind`` it should produce.
    struct DetectionCase: CustomTestStringConvertible, Sendable {
        let label: String
        /// Relative path to create. Trailing `/` means directory.
        let marker: String
        let expected: ProjectKind

        var testDescription: String { label }
    }

    @Test(
        "Detects project kind from a single marker",
        arguments: [
            DetectionCase(label: ".git directory -> code", marker: ".git/", expected: .code),
            DetectionCase(label: "Package.swift -> code", marker: "Package.swift", expected: .code),
            DetectionCase(label: "notes.md -> writing", marker: "notes.md", expected: .writing),
            DetectionCase(label: "data.csv -> research", marker: "data.csv", expected: .research),
            DetectionCase(label: "empty directory -> unknown", marker: "", expected: .unknown),
        ]
    )
    func detectsSingleMarker(_ testCase: DetectionCase) throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        if !testCase.marker.isEmpty {
            if testCase.marker.hasSuffix("/") {
                let name = String(testCase.marker.dropLast())
                try FileManager.default.createDirectory(
                    at: dir.appendingPathComponent(name, isDirectory: true),
                    withIntermediateDirectories: true
                )
            } else {
                FileManager.default.createFile(
                    atPath: dir.appendingPathComponent(testCase.marker).path,
                    contents: Data("content".utf8)
                )
            }
        }

        #expect(ProjectDetector.detect(at: dir) == testCase.expected)
    }

    // MARK: - Mixed detection

    @Test("Detects mixed when code and writing markers coexist")
    func detectsMixedFromCodeAndWriting() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("Package.swift").path,
            contents: Data("// pkg".utf8)
        )
        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("README.md").path,
            contents: Data("# Readme".utf8)
        )

        #expect(ProjectDetector.detect(at: dir) == .mixed)
    }

    // MARK: - Context file detection

    @Test("CLAUDE.md is detected as context file")
    func hasContextFileDetectsCLAUDEmd() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("CLAUDE.md").path,
            contents: Data("# Context".utf8)
        )

        #expect(ProjectDetector.hasContextFile(at: dir))
    }

    @Test("Returns false when no context file present")
    func hasContextFileReturnsFalseWhenAbsent() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        #expect(!ProjectDetector.hasContextFile(at: dir))
    }
}
