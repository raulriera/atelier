import Foundation
import Testing
@testable import AtelierKit

@Suite("PatternTracker")
struct PatternTrackerTests {

    /// Creates a tracker backed by a temporary directory that's cleaned up after the test.
    private func makeTracker() throws -> (PatternTracker, URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatternTrackerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let tracker = PatternTracker(projectRoot: tmp)
        return (tracker, tmp)
    }

    private func cleanup(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Normalization

    @Test("Normalize strips leading bullet and lowercases")
    func normalizeBasic() {
        #expect(PatternTracker.normalize("- Use DD/MM/YYYY") == "use dd/mm/yyyy")
        #expect(PatternTracker.normalize("  Hello World  ") == "hello world")
        #expect(PatternTracker.normalize("- ") == "")
    }

    @Test("Normalize handles entries without bullet prefix")
    func normalizeNoBullet() {
        #expect(PatternTracker.normalize("Prefers dark mode") == "prefers dark mode")
    }

    @Test("Normalize handles bare dash without trailing space")
    func normalizeBareDash() {
        #expect(PatternTracker.normalize("-") == "")
    }

    // MARK: - Parsing

    @Test("parseEntries extracts entries from standard distillation output")
    func parseStandardOutput() throws {
        let markdown = """
        ## Preferences
        - Use DD/MM/YYYY date format
        - Prefers bullet points over paragraphs

        ## Decisions
        - Chose Stripe over Square for recurring billing

        ## Patterns
        - Files organized by client name
        """

        let entries = PatternTracker.parseEntries(from: markdown)
        try #require(entries.count == 4)
        #expect(entries[0].text == "Use DD/MM/YYYY date format")
        #expect(entries[0].category == "Preferences")
        #expect(entries[2].text == "Chose Stripe over Square for recurring billing")
        #expect(entries[2].category == "Decisions")
        #expect(entries[3].category == "Patterns")
    }

    @Test("parseEntries ignores lines before any heading")
    func parseIgnoresOrphans() {
        let markdown = """
        Some preamble
        - Orphan bullet
        ## Preferences
        - Real entry
        """

        let entries = PatternTracker.parseEntries(from: markdown)
        #expect(entries.count == 1)
        #expect(entries[0].text == "Real entry")
    }

    @Test("parseEntries handles empty sections")
    func parseEmptySections() {
        let markdown = """
        ## Preferences

        ## Decisions
        - A decision
        """

        let entries = PatternTracker.parseEntries(from: markdown)
        #expect(entries.count == 1)
        #expect(entries[0].category == "Decisions")
    }

    // MARK: - Recording

    @Test("record adds entries with session ID")
    func recordBasic() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(
            entries: [("Use DD/MM/YYYY", "Preferences")],
            sessionID: "session-1"
        )

        let state = tracker.load()
        let obs = try #require(state.observations["use dd/mm/yyyy"])
        #expect(obs.text == "Use DD/MM/YYYY")
        #expect(obs.category == "Preferences")
        #expect(obs.sessions == ["session-1"])
    }

    @Test("record accumulates sessions for the same entry")
    func recordMultipleSessions() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("Use metric units", "Preferences")], sessionID: "s1")
        try tracker.record(entries: [("Use metric units", "Preferences")], sessionID: "s2")
        try tracker.record(entries: [("Use metric units", "Preferences")], sessionID: "s3")

        let state = tracker.load()
        let obs = try #require(state.observations["use metric units"])
        #expect(obs.sessions.count == 3)
        #expect(obs.sessions == ["s1", "s2", "s3"])
    }

    @Test("record is idempotent for the same session")
    func recordIdempotent() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("Dark mode", "Preferences")], sessionID: "s1")
        try tracker.record(entries: [("Dark mode", "Preferences")], sessionID: "s1")

        let state = tracker.load()
        let obs = try #require(state.observations["dark mode"])
        #expect(obs.sessions.count == 1)
    }

    @Test("record updates text to latest wording")
    func recordUpdatesText() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("use dark mode", "Preferences")], sessionID: "s1")
        try tracker.record(entries: [("Use Dark Mode", "Preferences")], sessionID: "s2")

        let state = tracker.load()
        let obs = try #require(state.observations["use dark mode"])
        #expect(obs.text == "Use Dark Mode")
        #expect(obs.sessions.count == 2)
    }

    @Test("record skips empty entries after normalization")
    func recordSkipsEmpty() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("- ", "Preferences"), ("", "Decisions")], sessionID: "s1")

        let state = tracker.load()
        #expect(state.observations.isEmpty)
    }

    // MARK: - Suggestions

    @Test("suggestable returns entries above threshold")
    func suggestableAboveThreshold() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("Pattern A", "Patterns")], sessionID: "s1")
        try tracker.record(entries: [("Pattern A", "Patterns")], sessionID: "s2")
        try tracker.record(entries: [("Pattern A", "Patterns")], sessionID: "s3")

        let state = tracker.load()
        let suggestions = tracker.suggestable(from: state)
        #expect(suggestions.count == 1)
        #expect(suggestions[0].text == "Pattern A")
    }

    @Test("suggestable excludes entries below threshold")
    func suggestableBelowThreshold() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("Pattern B", "Patterns")], sessionID: "s1")
        try tracker.record(entries: [("Pattern B", "Patterns")], sessionID: "s2")

        let state = tracker.load()
        let suggestions = tracker.suggestable(from: state)
        #expect(suggestions.isEmpty)
    }

    @Test("suggestable respects custom threshold")
    func suggestableCustomThreshold() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("Pattern C", "Patterns")], sessionID: "s1")
        try tracker.record(entries: [("Pattern C", "Patterns")], sessionID: "s2")

        let state = tracker.load()
        let suggestions = tracker.suggestable(from: state, threshold: 2)
        #expect(suggestions.count == 1)
    }

    @Test("suggestable excludes dismissed entries")
    func suggestableExcludesDismissed() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("Pattern D", "Patterns")], sessionID: "s1")
        try tracker.record(entries: [("Pattern D", "Patterns")], sessionID: "s2")
        try tracker.record(entries: [("Pattern D", "Patterns")], sessionID: "s3")
        try tracker.dismiss(text: "Pattern D")

        let state = tracker.load()
        let suggestions = tracker.suggestable(from: state)
        #expect(suggestions.isEmpty)
    }

    @Test("suggestable caps at maxSuggestions")
    func suggestableMaxCap() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        // Create more patterns than maxSuggestions
        for i in 0..<5 {
            let pattern = "Pattern \(i)"
            try tracker.record(entries: [(pattern, "Patterns")], sessionID: "s1")
            try tracker.record(entries: [(pattern, "Patterns")], sessionID: "s2")
            try tracker.record(entries: [(pattern, "Patterns")], sessionID: "s3")
        }

        let state = tracker.load()
        let suggestions = tracker.suggestable(from: state)
        #expect(suggestions.count == PatternTracker.maxSuggestions)
    }

    @Test("suggestable sorts by session count descending")
    func suggestableSortOrder() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        // Pattern with 4 sessions
        for sid in ["s1", "s2", "s3", "s4"] {
            try tracker.record(entries: [("Frequent", "Patterns")], sessionID: sid)
        }
        // Pattern with 3 sessions
        for sid in ["s1", "s2", "s3"] {
            try tracker.record(entries: [("Less frequent", "Patterns")], sessionID: sid)
        }

        let state = tracker.load()
        let suggestions = tracker.suggestable(from: state)
        try #require(suggestions.count == 2)
        #expect(suggestions[0].text == "Frequent")
        #expect(suggestions[1].text == "Less frequent")
    }

    // MARK: - Dismissal

    @Test("dismiss persists and isDismissed reflects it")
    func dismissPersistence() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        #expect(!tracker.isDismissed("Some pattern"))
        try tracker.dismiss(text: "Some pattern")
        #expect(tracker.isDismissed("Some pattern"))
    }

    @Test("dismiss normalizes text for matching")
    func dismissNormalized() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.dismiss(text: "- Use Dark Mode")
        #expect(tracker.isDismissed("use dark mode"))
        #expect(tracker.isDismissed("- Use Dark Mode"))
    }

    // MARK: - Pruning

    @Test("prune evicts stale single-session entries when over cap")
    func pruneEvictsStale() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        // Seed with more than maxObservations entries, each seen in 1 session
        var state = PatternTracker.State()
        for i in 0..<(PatternTracker.maxObservations + 10) {
            state.observations["entry-\(i)"] = .init(
                text: "Entry \(i)",
                category: "Patterns",
                sessions: ["old-session"]
            )
        }
        try tracker.save(state)

        // Prune with a set of current keys (these survive)
        try tracker.prune(currentKeys: ["entry-0", "entry-1"])

        let pruned = tracker.load()
        #expect(pruned.observations.count <= PatternTracker.maxObservations)
        #expect(pruned.observations["entry-0"] != nil)
        #expect(pruned.observations["entry-1"] != nil)
    }

    @Test("prune preserves multi-session entries")
    func pruneKeepsMultiSession() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        var state = PatternTracker.State()
        for i in 0..<(PatternTracker.maxObservations + 5) {
            state.observations["entry-\(i)"] = .init(
                text: "Entry \(i)",
                category: "Patterns",
                sessions: ["s1", "s2"] // multi-session — should not be evicted
            )
        }
        try tracker.save(state)

        try tracker.prune(currentKeys: [])

        let pruned = tracker.load()
        // Multi-session entries are never evicted, even over cap
        #expect(pruned.observations.count == PatternTracker.maxObservations + 5)
    }

    @Test("prune is a no-op when under cap")
    func pruneNoOpUnderCap() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        try tracker.record(entries: [("Pattern A", "Patterns")], sessionID: "s1")
        try tracker.prune(currentKeys: [])

        let state = tracker.load()
        #expect(state.observations.count == 1)
    }

    // MARK: - Persistence

    @Test("state round-trips through save and load")
    func roundTrip() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        var state = PatternTracker.State()
        state.observations["test"] = .init(
            text: "Test entry",
            category: "Preferences",
            sessions: ["s1", "s2"]
        )
        state.dismissed = ["old-pattern"]

        try tracker.save(state)
        let loaded = tracker.load()
        #expect(loaded == state)
    }

    @Test("load returns empty state when file is missing")
    func loadMissingFile() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        let state = tracker.load()
        #expect(state.observations.isEmpty)
        #expect(state.dismissed.isEmpty)
    }

    @Test("load returns empty state when file is corrupted")
    func loadCorruptedFile() throws {
        let (tracker, root) = try makeTracker()
        defer { cleanup(root) }

        let dir = tracker.storePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "not json".write(to: tracker.storePath, atomically: true, encoding: .utf8)

        let state = tracker.load()
        #expect(state.observations.isEmpty)
    }
}
