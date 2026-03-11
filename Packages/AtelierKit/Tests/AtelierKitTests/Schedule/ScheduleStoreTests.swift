import Foundation
import Testing
@testable import AtelierKit

/// No-op agent manager for tests — never touches launchd or the filesystem.
private struct StubAgentManager: LaunchAgentManaging {
    func install(calendarIntervals: [[String: Int]]) throws {}
    func uninstall() throws {}
}

@Suite("ScheduleStore")
@MainActor
struct ScheduleStoreTests {

    private func makeStore(persistenceURL: URL? = nil) -> ScheduleStore {
        ScheduleStore(persistenceURL: persistenceURL, agentManager: StubAgentManager())
    }

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-test-\(UUID().uuidString).json")
    }

    private func makeSampleTask(
        name: String = "Test task",
        schedule: TaskSchedule = .daily(hour: 9, minute: 0)
    ) -> ScheduledTask {
        ScheduledTask(
            name: name,
            prompt: "Do something",
            schedule: schedule,
            projectPath: "/tmp",
            projectId: UUID()
        )
    }

    // MARK: - Add

    @Test func addAppendsTask() {
        let store = makeStore()
        let task = makeSampleTask()

        store.add(task)

        #expect(store.tasks.count == 1)
        #expect(store.tasks.first?.id == task.id)
        #expect(store.tasks.first?.name == "Test task")
    }

    @Test func addMultipleTasks() {
        let store = makeStore()

        store.add(makeSampleTask(name: "First"))
        store.add(makeSampleTask(name: "Second"))

        #expect(store.tasks.count == 2)
        #expect(store.tasks[0].name == "First")
        #expect(store.tasks[1].name == "Second")
    }

    // MARK: - Remove

    @Test func removeDeletesTask() {
        let store = makeStore()
        let task = makeSampleTask()

        store.add(task)
        #expect(store.tasks.count == 1)

        store.remove(task.id)
        #expect(store.tasks.isEmpty)
    }

    @Test func removeNonexistentIdIsNoOp() {
        let store = makeStore()
        store.add(makeSampleTask())

        store.remove(UUID())
        #expect(store.tasks.count == 1)
    }

    // MARK: - Update

    @Test func updateModifiesExistingTask() {
        let store = makeStore()
        var task = makeSampleTask()

        store.add(task)
        task.name = "Updated name"
        task.schedule = .hourly
        store.update(task)

        #expect(store.tasks.first?.name == "Updated name")
        #expect(store.tasks.first?.schedule == .hourly)
    }

    @Test func updateNonexistentTaskIsNoOp() {
        let store = makeStore()
        store.add(makeSampleTask())

        let other = makeSampleTask(name: "Other")
        store.update(other)

        #expect(store.tasks.count == 1)
        #expect(store.tasks.first?.name == "Test task")
    }

    // MARK: - Toggle Pause

    @Test func togglePauseSetsAndUnsets() throws {
        let store = makeStore()
        let task = makeSampleTask()

        store.add(task)
        var current = try #require(store.tasks.first)
        #expect(!current.isPaused)

        store.togglePause(task.id)
        current = try #require(store.tasks.first)
        #expect(current.isPaused)

        store.togglePause(task.id)
        current = try #require(store.tasks.first)
        #expect(!current.isPaused)
    }

    @Test func togglePauseNonexistentIdIsNoOp() throws {
        let store = makeStore()
        store.add(makeSampleTask())

        store.togglePause(UUID())
        let current = try #require(store.tasks.first)
        #expect(!current.isPaused)
    }

    // MARK: - Persistence

    @Test func persistenceRoundTrip() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store1 = makeStore(persistenceURL: url)
        let task = makeSampleTask()
        store1.add(task)

        #expect(FileManager.default.fileExists(atPath: url.path))

        let store2 = makeStore(persistenceURL: url)
        store2.load()

        #expect(store2.tasks.count == 1)
        #expect(store2.tasks.first?.id == task.id)
        #expect(store2.tasks.first?.name == task.name)
        #expect(store2.tasks.first?.schedule == task.schedule)
    }

    @Test func loadWithNoFileProducesEmptyTasks() {
        let url = makeTempURL()
        let store = makeStore(persistenceURL: url)
        store.load()

        #expect(store.tasks.isEmpty)
    }

    @Test func loadWithMalformedFileDoesNotCrash() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try Data("not json".utf8).write(to: url)

        let store = makeStore(persistenceURL: url)
        store.load()

        #expect(store.tasks.isEmpty)
    }

    @Test func nilPersistenceURLIsInMemoryOnly() {
        let store = makeStore()
        store.add(makeSampleTask())

        #expect(store.tasks.count == 1)
    }

    // MARK: - Preview

    @Test func previewHasSampleData() {
        let store = ScheduleStore.preview

        #expect(!store.tasks.isEmpty)
        #expect(store.tasks.count == 3)
    }
}
