import Foundation
import Testing
@testable import AtelierKit

@Suite("MemoryStore")
struct MemoryStoreTests {
    private let manager = FileManager.default

    private func makeTempDir() throws -> URL {
        let url = manager.temporaryDirectory
            .appendingPathComponent("MemoryStoreTests-\(UUID().uuidString)")
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? manager.removeItem(at: url)
    }

    // MARK: - Category Read/Write

    @Test func writeCategoryCreatesDirectoryAndFile() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        try store.write(category: "## Preferences", content: "## Preferences\n- Use tabs")

        #expect(manager.fileExists(atPath: store.memoryDirectory.path))
        let content = try #require(store.read(category: "## Preferences"))
        #expect(content == "## Preferences\n- Use tabs")
    }

    @Test func writeCategoryOverwritesExisting() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        try store.write(category: "## Decisions", content: "first")
        try store.write(category: "## Decisions", content: "second")

        let content = try #require(store.read(category: "## Decisions"))
        #expect(content == "second")
    }

    @Test func readCategoryReturnsNilWhenAbsent() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        #expect(store.read(category: "## Preferences") == nil)
    }

    @Test func readCategoryReturnsNilForUnknownCategory() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        #expect(store.read(category: "## Unknown") == nil)
    }

    @Test func writeCategoryIgnoresUnknownCategory() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        try store.write(category: "## Unknown", content: "ignored")

        #expect(store.listFiles().isEmpty)
    }

    // MARK: - Read All

    @Test func readAllCombinesMultipleFiles() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        try store.write(category: "## Preferences", content: "## Preferences\n- Use tabs")
        try store.write(category: "## Decisions", content: "## Decisions\n- Chose SwiftUI")

        let combined = try #require(store.readAll())
        #expect(combined.contains("## Preferences"))
        #expect(combined.contains("## Decisions"))
        #expect(combined.contains("- Use tabs"))
        #expect(combined.contains("- Chose SwiftUI"))
    }

    @Test func readAllReturnsNilWhenEmpty() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        #expect(store.readAll() == nil)
    }

    @Test func readAllSortsFilesByName() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        try store.write(category: "## Preferences", content: "## Preferences\n- tabs")
        try store.write(category: "## Corrections", content: "## Corrections\n- fix")

        let combined = try #require(store.readAll())
        let correctionsIndex = combined.range(of: "## Corrections")!.lowerBound
        let preferencesIndex = combined.range(of: "## Preferences")!.lowerBound
        // corrections.md sorts before preferences.md
        #expect(correctionsIndex < preferencesIndex)
    }

    // MARK: - List Files

    @Test func listFilesReturnsAllMemoryFiles() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        try store.write(category: "## Preferences", content: "content")
        try store.write(category: "## Patterns", content: "content")

        let files = store.listFiles()
        let names = files.map { $0.lastPathComponent }
        #expect(names.contains("preferences.md"))
        #expect(names.contains("patterns.md"))
        #expect(files.count == 2)
    }

    @Test func listFilesReturnsEmptyWhenNoDirectory() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        #expect(store.listFiles().isEmpty)
    }

    // MARK: - Categories

    @Test func categoriesMapToCorrectFilenames() {
        let map = Dictionary(
            uniqueKeysWithValues: MemoryStore.categories.map { ($0.heading, $0.filename) }
        )
        #expect(map["## Preferences"] == "preferences.md")
        #expect(map["## Decisions"] == "decisions.md")
        #expect(map["## Patterns"] == "patterns.md")
        #expect(map["## Corrections"] == "corrections.md")
    }
}
