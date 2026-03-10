import Foundation
import Testing
@testable import AtelierKit

@Suite("EntryAgeTracker")
struct EntryAgeTrackerTests {
    private let manager = FileManager.default

    private func makeTempDir() throws -> URL {
        let url = manager.temporaryDirectory
            .appendingPathComponent("EntryAgeTests-\(UUID().uuidString)")
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? manager.removeItem(at: url)
    }

    // MARK: - Load / Save

    @Test("loads empty state when no file exists")
    func loadsEmptyState() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let tracker = EntryAgeTracker(memoryDirectory: dir)
        let state = tracker.load()
        #expect(state.entries.isEmpty)
    }

    @Test("round-trips state through JSON")
    func roundTrips() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let tracker = EntryAgeTracker(memoryDirectory: dir)
        var state = EntryAgeTracker.State()
        state.entries["use tabs"] = .init(category: "Preferences", runsSinceLastSeen: 3)
        try tracker.save(state)

        let loaded = tracker.load()
        let entry = try #require(loaded.entries["use tabs"])
        #expect(entry.category == "Preferences")
        #expect(entry.runsSinceLastSeen == 3)
    }

    // MARK: - Update

    @Test("resets age for current entries")
    func resetsAgeForCurrent() {
        var state = EntryAgeTracker.State()
        state.entries["use tabs"] = .init(category: "Preferences", runsSinceLastSeen: 7)

        let _ = EntryAgeTracker.update(
            state: &state,
            currentEntries: [("Use tabs", "Preferences")]
        )

        let entry = state.entries["use tabs"]
        #expect(entry?.runsSinceLastSeen == 0)
    }

    @Test("increments age for absent entries")
    func incrementsAgeForAbsent() {
        var state = EntryAgeTracker.State()
        state.entries["old decision"] = .init(category: "Decisions", runsSinceLastSeen: 3)

        let _ = EntryAgeTracker.update(
            state: &state,
            currentEntries: [("New pattern", "Patterns")]
        )

        let entry = state.entries["old decision"]
        #expect(entry?.runsSinceLastSeen == 4)
    }

    @Test("adds new entries with age 0")
    func addsNewEntries() {
        var state = EntryAgeTracker.State()

        let _ = EntryAgeTracker.update(
            state: &state,
            currentEntries: [("Brand new entry", "Patterns")]
        )

        let entry = state.entries["brand new entry"]
        #expect(entry?.runsSinceLastSeen == 0)
        #expect(entry?.category == "Patterns")
    }

    @Test("returns archivable entries at threshold")
    func returnsArchivable() {
        var state = EntryAgeTracker.State()
        state.entries["stale item"] = .init(category: "Decisions", runsSinceLastSeen: 19)

        let archivable = EntryAgeTracker.update(
            state: &state,
            currentEntries: [("Fresh item", "Patterns")]
        )

        #expect(archivable.count == 1)
        #expect(archivable.first?.key == "stale item")
        #expect(state.entries["stale item"]?.runsSinceLastSeen == 20)
    }

    @Test("does not flag entries below threshold")
    func doesNotFlagBelowThreshold() {
        var state = EntryAgeTracker.State()
        state.entries["recent item"] = .init(category: "Patterns", runsSinceLastSeen: 10)

        let archivable = EntryAgeTracker.update(
            state: &state,
            currentEntries: [("Other", "Patterns")]
        )

        #expect(archivable.isEmpty)
    }

    // MARK: - Remove Archived

    @Test("removes archived keys from state")
    func removesArchivedKeys() {
        var state = EntryAgeTracker.State()
        state.entries["keep"] = .init(category: "Preferences", runsSinceLastSeen: 0)
        state.entries["remove"] = .init(category: "Decisions", runsSinceLastSeen: 25)

        EntryAgeTracker.removeArchived(state: &state, keys: ["remove"])

        #expect(state.entries["keep"] != nil)
        #expect(state.entries["remove"] == nil)
    }

    // MARK: - Age Annotations

    @Test("annotates aging entries with age suffix")
    func annotatesAgingEntries() {
        var state = EntryAgeTracker.State()
        state.entries["use tabs"] = .init(category: "Preferences", runsSinceLastSeen: 8)

        let content = "## Preferences\n- Use tabs\n- Use dark mode"
        let annotated = EntryAgeTracker.annotateWithAge(content: content, state: state)

        #expect(annotated.contains("- Use tabs [age: 8 runs]"))
        #expect(annotated.contains("- Use dark mode"))
        #expect(!annotated.contains("dark mode [age:"))
    }

    @Test("does not annotate entries below aging threshold")
    func doesNotAnnotateFresh() {
        var state = EntryAgeTracker.State()
        state.entries["use tabs"] = .init(category: "Preferences", runsSinceLastSeen: 3)

        let content = "## Preferences\n- Use tabs"
        let annotated = EntryAgeTracker.annotateWithAge(content: content, state: state)

        #expect(!annotated.contains("[age:"))
    }

    @Test("preserves non-bullet lines unchanged")
    func preservesHeadings() {
        let state = EntryAgeTracker.State()
        let content = "## Preferences\n- Use tabs"
        let annotated = EntryAgeTracker.annotateWithAge(content: content, state: state)

        #expect(annotated.contains("## Preferences"))
    }

    // MARK: - Normalize

    @Test("normalizes text consistently")
    func normalizesText() {
        #expect(EntryAgeTracker.normalize("- Use TABS") == "use tabs")
        #expect(EntryAgeTracker.normalize("Use tabs") == "use tabs")
        #expect(EntryAgeTracker.normalize("  Whitespace  ") == "whitespace")
    }
}
