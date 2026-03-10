import Foundation

/// Tracks how many distillation runs have passed since each memory entry
/// was last produced. Enables progressive decay: aging entries get
/// condensed, very old entries get archived.
///
/// Age increments per distillation run (fired on every `Stop` and
/// `PreCompact` hook), not per session. This means decay works equally
/// well for many short sessions and few long conversations.
///
/// Persisted as `.atelier/memory/entry-age.json`.
public struct EntryAgeTracker: Sendable {

    /// Per-entry age metadata.
    public struct Entry: Codable, Sendable {
        /// The category heading (e.g. "Preferences").
        public var category: String
        /// Number of distillation runs since this entry last appeared in output.
        public var runsSinceLastSeen: Int

        public init(category: String, runsSinceLastSeen: Int = 0) {
            self.category = category
            self.runsSinceLastSeen = runsSinceLastSeen
        }
    }

    /// Full tracker state on disk.
    public struct State: Codable, Sendable {
        /// Keyed by normalized entry text.
        public var entries: [String: Entry]

        public init(entries: [String: Entry] = [:]) {
            self.entries = entries
        }
    }

    /// Entries older than this threshold are candidates for archival.
    public static let archiveThreshold = 20

    /// Entries between these bounds get age annotations in the prompt.
    public static let agingThreshold = 5

    static let filename = "entry-age.json"

    private let memoryDirectory: URL

    public init(memoryDirectory: URL) {
        self.memoryDirectory = memoryDirectory
    }

    // MARK: - Load / Save

    public func load() -> State {
        let url = memoryDirectory.appendingPathComponent(Self.filename)
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return State() }
        return state
    }

    public func save(_ state: State) throws {
        try FileManager.default.createDirectory(
            at: memoryDirectory,
            withIntermediateDirectories: true
        )
        let url = memoryDirectory.appendingPathComponent(Self.filename)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Update

    /// Updates the age tracker after a distillation run.
    ///
    /// - Entries present in `currentEntries` get their age reset to 0.
    /// - Entries not present get their age incremented.
    /// - New entries are added with age 0.
    ///
    /// Returns the entries that crossed the archive threshold.
    public static func update(
        state: inout State,
        currentEntries: [(text: String, category: String)]
    ) -> [(key: String, entry: Entry)] {
        let currentKeys = Set(currentEntries.map { normalize($0.text) })

        // Reset age for current entries, add new ones
        for (text, category) in currentEntries {
            let key = normalize(text)
            state.entries[key] = Entry(category: category, runsSinceLastSeen: 0)
        }

        // Increment age for absent entries, collect archive candidates
        var archivable: [(key: String, entry: Entry)] = []
        for (key, var entry) in state.entries where !currentKeys.contains(key) {
            entry.runsSinceLastSeen += 1
            state.entries[key] = entry
            if entry.runsSinceLastSeen >= archiveThreshold {
                archivable.append((key, entry))
            }
        }

        return archivable
    }

    /// Removes archived entries from the tracker state.
    public static func removeArchived(state: inout State, keys: [String]) {
        for key in keys {
            state.entries.removeValue(forKey: key)
        }
    }

    // MARK: - Age Annotations

    /// Annotates existing learnings with age metadata so Haiku can
    /// condense aging entries during distillation.
    ///
    /// Entries with `runsSinceLastSeen >= agingThreshold` get an
    /// `[age: N runs]` suffix appended to their bullet line.
    public static func annotateWithAge(
        content: String,
        state: State
    ) -> String {
        content.components(separatedBy: .newlines).map { line in
            guard line.hasPrefix("- ") else { return line }
            let text = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            let key = normalize(text)
            guard let entry = state.entries[key],
                  entry.runsSinceLastSeen >= agingThreshold
            else { return line }
            return "\(line) [age: \(entry.runsSinceLastSeen) runs]"
        }.joined(separator: "\n")
    }

    // MARK: - Normalize

    /// Normalizes entry text for stable matching across distillation runs.
    public static func normalize(_ text: String) -> String {
        var t = text
        if t.hasPrefix("- ") { t = String(t.dropFirst(2)) }
        return t.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
