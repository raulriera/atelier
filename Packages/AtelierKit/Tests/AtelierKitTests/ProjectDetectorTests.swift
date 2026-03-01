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

    @Test func detectsCodeFromGitDirectory() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )

        #expect(ProjectDetector.detect(at: dir) == .code)
    }

    @Test func detectsCodeFromPackageSwift() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("Package.swift").path,
            contents: Data("// swift package".utf8)
        )

        #expect(ProjectDetector.detect(at: dir) == .code)
    }

    @Test func detectsWritingFromMarkdownFiles() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("notes.md").path,
            contents: Data("# Notes".utf8)
        )

        #expect(ProjectDetector.detect(at: dir) == .writing)
    }

    @Test func detectsResearchFromCSV() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("data.csv").path,
            contents: Data("a,b,c".utf8)
        )

        #expect(ProjectDetector.detect(at: dir) == .research)
    }

    @Test func detectsMixedFromCodeAndWriting() throws {
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

    @Test func detectsUnknownForEmptyDirectory() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        #expect(ProjectDetector.detect(at: dir) == .unknown)
    }

    @Test func hasContextFileDetectsCLAUDEmd() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("CLAUDE.md").path,
            contents: Data("# Context".utf8)
        )

        #expect(ProjectDetector.hasContextFile(at: dir))
    }

    @Test func hasContextFileReturnsFalseWhenAbsent() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        #expect(!ProjectDetector.hasContextFile(at: dir))
    }
}
