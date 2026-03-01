import Testing
import Foundation
@testable import AtelierKit
import AtelierSecurity

@Suite("ProjectMigration")
struct ProjectMigrationTests {

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @MainActor
    private func makeStore(baseDirectory: URL) -> ProjectStore {
        ProjectStore(baseDirectory: baseDirectory, bookmarkCreator: MockBookmarkCreator())
    }

    @Test @MainActor func migratesGlobalSessionsAndBookmarks() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        // Set up global state
        let globalSessions = base.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: globalSessions, withIntermediateDirectories: true)
        let sessionData = Data("{\"sessionId\":\"old-session\",\"items\":[],\"savedAt\":\"2024-01-01T00:00:00Z\"}".utf8)
        try sessionData.write(to: globalSessions.appendingPathComponent("old-session.json"))

        let globalBookmarks = base.appendingPathComponent("bookmarks.json")
        try Data("[]".utf8).write(to: globalBookmarks)

        #expect(ProjectMigration.isMigrationNeeded(baseDirectory: base))

        let store = makeStore(baseDirectory: base)
        let projectID = try ProjectMigration.migrateGlobalState(
            baseDirectory: base,
            projectStore: store
        )

        // Verify session was moved into project directory
        let projectDir = store.projectDirectory(for: projectID)
        let migratedSession = projectDir
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent("old-session.json")
        #expect(FileManager.default.fileExists(atPath: migratedSession.path))

        // Verify bookmarks were moved
        let migratedBookmarks = projectDir.appendingPathComponent("bookmarks.json")
        #expect(FileManager.default.fileExists(atPath: migratedBookmarks.path))

        // Verify global files are cleaned up
        #expect(!FileManager.default.fileExists(atPath: globalBookmarks.path))
    }

    @Test @MainActor func isMigrationNeededReturnsFalseAfterMigration() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        // Set up global state
        let globalSessions = base.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: globalSessions, withIntermediateDirectories: true)
        let sessionData = Data("{}".utf8)
        try sessionData.write(to: globalSessions.appendingPathComponent("test.json"))

        #expect(ProjectMigration.isMigrationNeeded(baseDirectory: base))

        let store = makeStore(baseDirectory: base)
        _ = try ProjectMigration.migrateGlobalState(
            baseDirectory: base,
            projectStore: store
        )

        // After migration, projects.json exists so migration is not needed
        #expect(!ProjectMigration.isMigrationNeeded(baseDirectory: base))
    }

    @Test func noopWhenNothingToMigrate() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        #expect(!ProjectMigration.isMigrationNeeded(baseDirectory: base))
    }
}

// MARK: - Mock

private struct MockBookmarkCreator: BookmarkCreator {
    func createBookmarkData(for url: URL, readOnly: Bool) throws -> Data {
        Data("mock-bookmark-\(url.path)".utf8)
    }
}
