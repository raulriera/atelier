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

    @Test func readLearningsReturnsNilWhenFileAbsent() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        #expect(store.readLearnings() == nil)
    }

    @Test func writeLearningsCreatesDirectoryAndFile() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        try store.writeLearnings("## Preferences\n- Use bullet lists")

        #expect(manager.fileExists(atPath: store.memoryDirectory.path))
        let content = try #require(store.readLearnings())
        #expect(content == "## Preferences\n- Use bullet lists")
    }

    @Test func writeLearningsOverwritesExisting() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        try store.writeLearnings("first version")
        try store.writeLearnings("second version")

        let content = try #require(store.readLearnings())
        #expect(content == "second version")
    }

    @Test func learningsURLPointsToCorrectPath() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let store = MemoryStore(projectRoot: dir)
        #expect(store.learningsURL.lastPathComponent == "learnings.md")
        #expect(store.learningsURL.deletingLastPathComponent().lastPathComponent == "memory")
    }
}
