import Foundation
import Testing
@testable import AtelierKit

@Suite("ContextFileLoader")
struct ContextFileLoaderTests {
    private let manager = FileManager.default

    /// Creates a temporary directory and returns its URL. Caller should clean up.
    private func makeTempDir() throws -> URL {
        let url = manager.temporaryDirectory
            .appendingPathComponent("ContextFileLoaderTests-\(UUID().uuidString)")
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? manager.removeItem(at: url)
    }

    // MARK: - discover

    @Test func discoverFindsCLAUDEmdAsNativeCLI() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let file = dir.appendingPathComponent("CLAUDE.md")
        try "# Project context".write(to: file, atomically: true, encoding: .utf8)

        let results = ContextFileLoader.discover(from: dir)
        #expect(results.count == 1)
        #expect(results[0].filename == "CLAUDE.md")
        #expect(results[0].source == .nativeCLI)
    }

    @Test func discoverFindsCoworkAsAtelierInjected() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let file = dir.appendingPathComponent("COWORK.md")
        try "# Cowork".write(to: file, atomically: true, encoding: .utf8)

        let results = ContextFileLoader.discover(from: dir)
        #expect(results.count == 1)
        #expect(results[0].filename == "COWORK.md")
        #expect(results[0].source == .atelierInjected)
    }

    @Test func discoverFindsAtelierContextAsAtelierInjected() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let atelierDir = dir.appendingPathComponent(".atelier")
        try manager.createDirectory(at: atelierDir, withIntermediateDirectories: true)
        let file = atelierDir.appendingPathComponent("context.md")
        try "# Atelier context".write(to: file, atomically: true, encoding: .utf8)

        let results = ContextFileLoader.discover(from: dir)
        #expect(results.count == 1)
        #expect(results[0].filename == "context.md")
        #expect(results[0].source == .atelierInjected)
    }

    @Test func directoryWalkFindsParentFiles() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let child = parent.appendingPathComponent("subproject")
        try manager.createDirectory(at: child, withIntermediateDirectories: true)

        // Parent has CLAUDE.md
        try "# Root".write(
            to: parent.appendingPathComponent("CLAUDE.md"),
            atomically: true, encoding: .utf8
        )
        // Child has COWORK.md
        try "# Child".write(
            to: child.appendingPathComponent("COWORK.md"),
            atomically: true, encoding: .utf8
        )

        let results = ContextFileLoader.discover(from: child)
        #expect(results.count == 2)
        // Child-first order
        #expect(results[0].filename == "COWORK.md")
        #expect(results[1].filename == "CLAUDE.md")
    }

    @Test func childFilesPrecedeParentFiles() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let child = parent.appendingPathComponent("inner")
        try manager.createDirectory(at: child, withIntermediateDirectories: true)

        try "# Parent".write(
            to: parent.appendingPathComponent("CLAUDE.md"),
            atomically: true, encoding: .utf8
        )
        try "# Child".write(
            to: child.appendingPathComponent("CLAUDE.md"),
            atomically: true, encoding: .utf8
        )

        let results = ContextFileLoader.discover(from: child)
        #expect(results.count >= 2)
        // The child's file should come first
        #expect(results[0].url.path.contains("inner"))
    }

    @Test func emptyDirectoryReturnsEmpty() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let results = ContextFileLoader.discover(from: dir)
        // May find files in parent directories (e.g. user's home), but none from this dir
        let localResults = results.filter { $0.url.path.hasPrefix(dir.path) }
        #expect(localResults.isEmpty)
    }

    // MARK: - contentForInjection

    @Test func contentForInjectionReturnsNilForOnlyNativeFiles() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        try "# Project".write(
            to: dir.appendingPathComponent("CLAUDE.md"),
            atomically: true, encoding: .utf8
        )

        let files = ContextFileLoader.discover(from: dir)
        let localFiles = files.filter { $0.url.path.hasPrefix(dir.path) }
        let content = ContextFileLoader.contentForInjection(from: localFiles)
        #expect(content == nil)
    }

    @Test("Content for injection concatenates multiple files")
    func contentForInjectionConcatenatesMultipleFiles() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        try "First file".write(
            to: dir.appendingPathComponent("COWORK.md"),
            atomically: true, encoding: .utf8
        )

        let atelierDir = dir.appendingPathComponent(".atelier")
        try manager.createDirectory(at: atelierDir, withIntermediateDirectories: true)
        try "Second file".write(
            to: atelierDir.appendingPathComponent("context.md"),
            atomically: true, encoding: .utf8
        )

        let files = ContextFileLoader.discover(from: dir)
        let localFiles = files.filter { $0.url.path.hasPrefix(dir.path) }
        let content = try #require(ContextFileLoader.contentForInjection(from: localFiles))

        #expect(content.contains("First file"))
        #expect(content.contains("Second file"))
        #expect(content.contains("---"))
    }

    // MARK: - Memory files

    @Test func discoverFindsMemoryFilesAtProjectRoot() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let memoryDir = dir
            .appendingPathComponent(".atelier")
            .appendingPathComponent("memory")
        try manager.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Preferences".write(
            to: memoryDir.appendingPathComponent("learnings.md"),
            atomically: true, encoding: .utf8
        )

        let results = ContextFileLoader.discover(from: dir)
        let localResults = results.filter { $0.url.path.hasPrefix(dir.path) }
        #expect(localResults.count == 1)
        #expect(localResults[0].filename == "learnings.md")
        #expect(localResults[0].source == .atelierMemory)
    }

    @Test func memoryFilesNotScannedInParentDirectories() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let child = parent.appendingPathComponent("subproject")
        try manager.createDirectory(at: child, withIntermediateDirectories: true)

        // Put memory files in the parent (not the child project root)
        let memoryDir = parent
            .appendingPathComponent(".atelier")
            .appendingPathComponent("memory")
        try manager.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Parent learnings".write(
            to: memoryDir.appendingPathComponent("learnings.md"),
            atomically: true, encoding: .utf8
        )

        let results = ContextFileLoader.discover(from: child)
        let memoryResults = results.filter { $0.url.path.contains("memory") }
        #expect(memoryResults.isEmpty)
    }

    @Test func memoryFilesIgnoresNonMarkdown() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let memoryDir = dir
            .appendingPathComponent(".atelier")
            .appendingPathComponent("memory")
        try manager.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "learnings".write(
            to: memoryDir.appendingPathComponent("learnings.md"),
            atomically: true, encoding: .utf8
        )
        try "not markdown".write(
            to: memoryDir.appendingPathComponent("notes.txt"),
            atomically: true, encoding: .utf8
        )

        let results = ContextFileLoader.discover(from: dir)
        let localResults = results.filter { $0.url.path.hasPrefix(dir.path) }
        #expect(localResults.count == 1)
        #expect(localResults[0].filename == "learnings.md")
    }

    @Test func memoryFilesIncludedInInjection() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let memoryDir = dir
            .appendingPathComponent(".atelier")
            .appendingPathComponent("memory")
        try manager.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Preferences\n- Use bullet lists".write(
            to: memoryDir.appendingPathComponent("learnings.md"),
            atomically: true, encoding: .utf8
        )

        let files = ContextFileLoader.discover(from: dir)
        let localFiles = files.filter { $0.url.path.hasPrefix(dir.path) }
        let content = try #require(ContextFileLoader.contentForInjection(from: localFiles))
        #expect(content.contains("Use bullet lists"))
        #expect(content.contains("<project-memory>"))
        #expect(content.contains("Do NOT read, edit, or write"))
    }

    @Test func contentForInjectionReturnsNilForEmptyContent() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        // Create a COWORK.md with only whitespace
        try "   \n  ".write(
            to: dir.appendingPathComponent("COWORK.md"),
            atomically: true, encoding: .utf8
        )

        let files = ContextFileLoader.discover(from: dir)
        let localFiles = files.filter { $0.url.path.hasPrefix(dir.path) }
        let content = ContextFileLoader.contentForInjection(from: localFiles)
        #expect(content == nil)
    }
}
