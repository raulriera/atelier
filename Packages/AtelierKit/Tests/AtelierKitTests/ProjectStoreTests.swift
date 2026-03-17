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

    @Test @MainActor func allProjectsSortedByLastOpenedAt() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)

        let olderMeta = ProjectMetadata(displayName: "Older", lastOpenedAt: Date(timeIntervalSince1970: 1000))
        store.storeMetadata(olderMeta)

        let newerMeta = ProjectMetadata(displayName: "Newer", lastOpenedAt: Date(timeIntervalSince1970: 2000))
        store.storeMetadata(newerMeta)

        let all = store.allProjects()
        try #require(all.count == 2)
        #expect(all[0].id == newerMeta.id)
        #expect(all[1].id == olderMeta.id)
    }

    @Test @MainActor func touchUpdatesLastOpenedAt() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)
        let originalDate = metadata.lastOpenedAt

        try store.touch(metadata.id)

        let updated = try #require(store.project(for: metadata.id))
        #expect(updated.lastOpenedAt > originalDate)
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
        let loaded = try #require(await project.sessionPersistence.load(id: "test-session"))
        #expect(loaded.sessionId == "test-session")
    }

    @Test @MainActor func findProjectByRootURL() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let projectRoot = base.appendingPathComponent("MyProject", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

        let metadata = try store.createProject(rootURL: projectRoot)
        let found = try #require(store.findProject(rootURL: projectRoot))
        #expect(found.id == metadata.id)
    }

    @Test @MainActor func findProjectReturnsNilForUnknownURL() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let found = store.findProject(rootURL: URL(fileURLWithPath: "/nonexistent"))

        #expect(found == nil)
    }

    // MARK: - nextUnclaimedProject (window restoration fallback)

    @Test @MainActor func nextUnclaimedProjectReturnsDifferentProjectEachCall() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let older = try store.createProject(rootURL: nil)
        let newer = try store.createProject(rootURL: nil)

        let first = try store.nextUnclaimedProject()
        let second = try store.nextUnclaimedProject()

        #expect(first.id != second.id)
        // Both existing projects claimed, no new ones created
        #expect(Set([first.id, second.id]) == Set([older.id, newer.id]))
        #expect(store.allProjects().count == 2)
    }

    @Test @MainActor func nextUnclaimedProjectCreatesScratchpadWhenAllClaimed() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let only = try store.createProject(rootURL: nil)

        let first = try store.nextUnclaimedProject()
        #expect(first.id == only.id)

        // All claimed — should create a new one
        let second = try store.nextUnclaimedProject()
        #expect(second.id != only.id)
        #expect(store.allProjects().count == 2)
    }

    @Test @MainActor func nextUnclaimedProjectPrefersRealProjectsOverScratchpads() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)

        let projectRoot = base.appendingPathComponent("RealProject", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

        let realProject = try store.createProject(rootURL: projectRoot)
        // Scratchpad is "more recent" by lastOpenedAt
        let scratchpad = ProjectMetadata(
            displayName: "Untitled",
            lastOpenedAt: Date(timeIntervalSinceNow: 100)
        )
        store.storeMetadata(scratchpad)

        // Should pick the real project first despite the scratchpad being newer
        let first = try store.nextUnclaimedProject()
        #expect(first.id == realProject.id)
        #expect(first.rootURL == projectRoot)
    }

    @Test @MainActor func nextUnclaimedProjectDoesNotUpdateLastOpenedAt() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)
        let originalDate = metadata.lastOpenedAt

        let restored = try store.nextUnclaimedProject()

        #expect(restored.id == metadata.id)
        let current = try #require(store.project(for: metadata.id))
        #expect(current.lastOpenedAt == originalDate)
    }

    @Test @MainActor func nextUnclaimedProjectCreatesWhenEmpty() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        #expect(store.allProjects().isEmpty)

        let result = try store.nextUnclaimedProject()
        #expect(result.displayName == "Untitled")
        #expect(store.allProjects().count == 1)
    }

    // MARK: - Open Window Tracking

    @Test @MainActor func registerOpenWindowPersistsToDisk() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let project = try store.createProject(rootURL: nil)

        store.registerOpenWindow(id: project.id)

        let url = base.appendingPathComponent("open-windows.json")
        try #require(FileManager.default.fileExists(atPath: url.path))

        let data = try Data(contentsOf: url)
        let ids = try JSONDecoder().decode([UUID].self, from: data)
        #expect(ids == [project.id])
    }

    @Test @MainActor func registerOpenWindowIsIdempotent() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let project = try store.createProject(rootURL: nil)

        store.registerOpenWindow(id: project.id)
        store.registerOpenWindow(id: project.id)
        store.registerOpenWindow(id: project.id)

        let url = base.appendingPathComponent("open-windows.json")
        let data = try Data(contentsOf: url)
        let ids = try JSONDecoder().decode([UUID].self, from: data)
        #expect(ids == [project.id])
    }

    @Test @MainActor func dequeueRestorationWindowReturnsPersistedIDs() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        // First session: register two open windows
        let store1 = makeStore(baseDirectory: base)
        try store1.load()
        let projectA = try store1.createProject(rootURL: nil)
        let projectB = try store1.createProject(rootURL: nil)
        store1.registerOpenWindow(id: projectA.id)
        store1.registerOpenWindow(id: projectB.id)

        // Second session: load and dequeue
        let store2 = makeStore(baseDirectory: base)
        try store2.load()

        let first = try #require(store2.dequeueRestorationWindow())
        let second = try #require(store2.dequeueRestorationWindow())
        let third = store2.dequeueRestorationWindow()

        #expect(first == projectA.id)
        #expect(second == projectB.id)
        #expect(third == nil)
    }

    @Test @MainActor func dequeueRestorationWindowSkipsDeletedProjects() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store1 = makeStore(baseDirectory: base)
        try store1.load()
        let projectA = try store1.createProject(rootURL: nil)
        let projectB = try store1.createProject(rootURL: nil)
        store1.registerOpenWindow(id: projectA.id)
        store1.registerOpenWindow(id: projectB.id)

        // Delete projectA before next launch
        try store1.deleteProject(projectA.id)

        let store2 = makeStore(baseDirectory: base)
        try store2.load()

        let first = store2.dequeueRestorationWindow()
        let second = store2.dequeueRestorationWindow()

        #expect(first == projectB.id)
        #expect(second == nil)
    }

    @Test @MainActor func dequeueRestorationWindowClaimsIDsForNextUnclaimedFallback() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store1 = makeStore(baseDirectory: base)
        try store1.load()
        let projectA = try store1.createProject(rootURL: nil)
        let projectB = try store1.createProject(rootURL: nil)
        store1.registerOpenWindow(id: projectA.id)

        // Second session: dequeue A, then fallback should skip A
        let store2 = makeStore(baseDirectory: base)
        try store2.load()

        let dequeued = store2.dequeueRestorationWindow()
        #expect(dequeued == projectA.id)

        // nextUnclaimedProject should not return projectA again
        let fallback = try store2.nextUnclaimedProject()
        #expect(fallback.id == projectB.id)
    }

    @Test @MainActor func deleteProjectRemovesFromOpenWindows() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let project = try store.createProject(rootURL: nil)
        store.registerOpenWindow(id: project.id)

        try store.deleteProject(project.id)

        let url = base.appendingPathComponent("open-windows.json")
        let data = try Data(contentsOf: url)
        let ids = try JSONDecoder().decode([UUID].self, from: data)
        #expect(ids.isEmpty)
    }

    // MARK: - updateProjectRoot

    @Test @MainActor func updateProjectRootUpdatesMetadataAndPersists() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)

        #expect(metadata.rootURL == nil)
        #expect(metadata.displayName == "Untitled")

        let projectRoot = base.appendingPathComponent("MyProject", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

        try store.updateProjectRoot(metadata.id, rootURL: projectRoot)

        let updated = try #require(store.project(for: metadata.id))
        #expect(updated.rootURL == projectRoot)
        #expect(updated.displayName == "MyProject")

        // Verify persisted
        let store2 = makeStore(baseDirectory: base)
        try store2.load()
        let reloaded = try #require(store2.project(for: metadata.id))
        #expect(reloaded.rootURL == projectRoot)
        #expect(reloaded.displayName == "MyProject")
    }

    @Test @MainActor func registryRoundTripsThroughSaveAndLoad() throws {
        let base = try makeTempDirectory()
        defer { cleanup(base) }

        let store = makeStore(baseDirectory: base)
        let metadata = try store.createProject(rootURL: nil)

        // Create a new store pointing to the same directory
        let store2 = makeStore(baseDirectory: base)
        try store2.load()

        let loaded = try #require(store2.project(for: metadata.id))
        #expect(loaded.id == metadata.id)
        #expect(loaded.displayName == metadata.displayName)
    }
}
