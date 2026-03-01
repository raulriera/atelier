import Testing
import Foundation
@testable import AtelierKit
import AtelierSecurity

@Suite("ProjectStore")
struct ProjectStoreTests {

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectStoreTests-\(UUID().uuidString)", isDirectory: true)
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

    @Test @MainActor func createProjectWithRootURLCreatesMetadataAndDirectory() async throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)

        // Create a folder to use as project root
        let projectRoot = base.appendingPathComponent("MyProject", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

        let metadata = try store.createProject(rootURL: projectRoot)

        #expect(metadata.rootURL == projectRoot)
        #expect(metadata.displayName == "MyProject")

        // Verify directory structure was created
        let projectDir = store.projectDirectory(for: metadata.id)
        let sessionsDir = projectDir.appendingPathComponent("sessions", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: sessionsDir.path))

        // Verify registry was saved
        #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent("projects.json").path))
    }

    @Test @MainActor func createScratchpadProjectSetsUntitled() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)

        #expect(metadata.rootURL == nil)
        #expect(metadata.displayName == "Untitled")
        #expect(metadata.detectedKind == .unknown)
    }

    @Test @MainActor func allProjectsSortedByLastOpenedAt() async throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)

        let older = try store.createProject(rootURL: nil)
        try await Task.sleep(for: .milliseconds(10))
        let newer = try store.createProject(rootURL: nil)

        let all = store.allProjects()
        #expect(all.count == 2)
        #expect(all[0].id == newer.id)
        #expect(all[1].id == older.id)
    }

    @Test @MainActor func touchUpdatesLastOpenedAt() async throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)
        let originalDate = metadata.lastOpenedAt

        try await Task.sleep(for: .milliseconds(10))
        try store.touch(metadata.id)

        let updated = store.project(for: metadata.id)
        #expect(updated != nil)
        #expect(updated!.lastOpenedAt > originalDate)
    }

    @Test @MainActor func deleteProjectRemovesMetadataAndDirectory() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)
        let projectDir = store.projectDirectory(for: metadata.id)

        #expect(FileManager.default.fileExists(atPath: projectDir.path))

        try store.deleteProject(metadata.id)

        #expect(store.project(for: metadata.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: projectDir.path))
    }

    @Test @MainActor func materializeReturnsProjectWithScopedPersistence() async throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)

        let project = try store.materialize(metadata.id)

        #expect(project.id == metadata.id)
        #expect(project.displayName == "Untitled")

        // Verify scoped persistence works by saving a session
        let snapshot = SessionSnapshot(
            sessionId: "test-session",
            items: [TimelineItem(content: .userMessage(UserMessage(text: "Hello")))],
            savedAt: Date()
        )
        try await project.sessionPersistence.save(snapshot)
        let loaded = try await project.sessionPersistence.load(id: "test-session")
        #expect(loaded != nil)
        #expect(loaded?.sessionId == "test-session")
    }

    @Test @MainActor func findProjectByRootURL() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let projectRoot = base.appendingPathComponent("MyProject", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

        let metadata = try store.createProject(rootURL: projectRoot)
        let found = store.findProject(rootURL: projectRoot)

        #expect(found != nil)
        #expect(found?.id == metadata.id)
    }

    @Test @MainActor func findProjectReturnsNilForUnknownURL() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let found = store.findProject(rootURL: URL(fileURLWithPath: "/nonexistent"))

        #expect(found == nil)
    }

    @Test @MainActor func openOrCreateReturnsExistingProject() async throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let original = try store.createProject(rootURL: nil)

        // Simulate what happens on every app launch when state restoration fails:
        // openOrCreateProject should return the existing project, not create a new one
        let returned = try store.openOrCreateProject()

        #expect(returned.id == original.id)
        #expect(store.allProjects().count == 1)
    }

    @Test @MainActor func openOrCreateReturnsMostRecentProject() async throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        _ = try store.createProject(rootURL: nil)
        try await Task.sleep(for: .milliseconds(10))
        let newer = try store.createProject(rootURL: nil)

        let returned = try store.openOrCreateProject()

        #expect(returned.id == newer.id)
        // Should not have created a third project
        #expect(store.allProjects().count == 2)
    }

    @Test @MainActor func openOrCreateCreatesScratchpadWhenEmpty() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)

        #expect(store.allProjects().isEmpty)

        let created = try store.openOrCreateProject()

        #expect(created.displayName == "Untitled")
        #expect(store.allProjects().count == 1)
    }

    // MARK: - nextRestoredProject (window restoration)

    @Test @MainActor func nextRestoredProjectReturnsDifferentProjectEachCall() async throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let older = try store.createProject(rootURL: nil)
        try await Task.sleep(for: .milliseconds(10))
        let newer = try store.createProject(rootURL: nil)

        // Simulates two restored windows calling defaultValue: back-to-back
        let first = try store.nextRestoredProject()
        let second = try store.nextRestoredProject()

        #expect(first.id == newer.id)
        #expect(second.id == older.id)
        #expect(first.id != second.id)
        // No extra projects created
        #expect(store.allProjects().count == 2)
    }

    @Test @MainActor func nextRestoredProjectCreatesScratchpadWhenEmpty() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let result = try store.nextRestoredProject()

        #expect(result.displayName == "Untitled")
        #expect(store.allProjects().count == 1)
    }

    @Test @MainActor func registryRoundTripsThroughSaveAndLoad() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)

        // Create a new store pointing to the same directory
        let store2 = makeStore(baseDirectory: base)
        try store2.load()

        let loaded = store2.project(for: metadata.id)
        #expect(loaded != nil)
        #expect(loaded?.id == metadata.id)
        #expect(loaded?.displayName == metadata.displayName)
    }
}

// MARK: - Mock

private struct MockBookmarkCreator: BookmarkCreator {
    func createBookmarkData(for url: URL, readOnly: Bool) throws -> Data {
        Data("mock-bookmark-\(url.path)".utf8)
    }
}
