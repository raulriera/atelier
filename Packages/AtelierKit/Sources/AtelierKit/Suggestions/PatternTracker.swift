import Foundation

/// Tracks pattern observations across sessions for proactive suggestions.
///
/// Each time distillation extracts a learning, it's recorded here with the
/// session ID. When the same learning appears across enough distinct sessions
/// (default: 3), it becomes a candidate for proactive suggestion — Claude
/// mentions it to the user so they can confirm, refine, or dismiss it.
///
/// Observations are keyed by normalized text (lowercased, trimmed) so that
/// minor wording variations across distillation runs match the same entry.
/// Dismissed patterns are permanently excluded from future suggestions.
///
/// - Important: This type does not provide concurrency safety for the
///   load-modify-save cycle. Callers must ensure serialized access
///   (e.g., by calling from a single process or serial context).
///   Current usage is single-writer: the `atelier-hooks` script (single-threaded)
///   writes, and the app reads for dismissal.
public struct PatternTracker: Sendable {
    /// Path to the persisted tracker state on disk.
    let storePath: URL

    /// Number of distinct sessions needed before suggesting a pattern.
    public static let defaultThreshold = 3

    /// Maximum suggestions to surface per startup.
    public static let maxSuggestions = 2

    public init(projectRoot: URL) {
        self.storePath = projectRoot
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
            .appendingPathComponent("pattern-tracker.json")
    }

    /// Creates a tracker pointing to a specific file path.
    public init(storePath: URL) {
        self.storePath = storePath
    }

    // MARK: - Data Model

    /// A single observed pattern with its session history.
    public struct Observation: Codable, Sendable, Equatable {
        /// The most recent wording of this learning.
        public var text: String
        /// Which memory category this belongs to (e.g. "Preferences").
        public var category: String
        /// Session IDs where this pattern was observed.
        public var sessions: Set<String>
    }

    /// The full persisted state.
    public struct State: Codable, Sendable, Equatable {
        /// Observations keyed by normalized text.
        public var observations: [String: Observation]
        /// Normalized keys of permanently dismissed patterns.
        public var dismissed: Set<String>

        public init(
            observations: [String: Observation] = [:],
            dismissed: Set<String> = []
        ) {
            self.observations = observations
            self.dismissed = dismissed
        }
    }

    // MARK: - Persistence

    /// Loads the current state from disk, or returns an empty state.
    public func load() -> State {
        guard let data = try? Data(contentsOf: storePath),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return State() }
        return state
    }

    /// Saves state to disk, creating the directory if needed.
    public func save(_ state: State) throws {
        let dir = storePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: storePath, options: .atomic)
    }

    // MARK: - Recording

    /// Records observations from a distillation result.
    ///
    /// Each entry is keyed by its normalized text. The session ID is added
    /// to the observation's session set — duplicate session IDs are ignored,
    /// so calling this twice with the same session is safe.
    public func record(
        entries: [(text: String, category: String)],
        sessionID: String
    ) throws {
        var state = load()
        for entry in entries {
            let key = Self.normalize(entry.text)
            guard !key.isEmpty else { continue }
            if var existing = state.observations[key] {
                existing.sessions.insert(sessionID)
                existing.text = entry.text
                state.observations[key] = existing
            } else {
                state.observations[key] = Observation(
                    text: entry.text,
                    category: entry.category,
                    sessions: [sessionID]
                )
            }
        }
        try save(state)
    }

    // MARK: - Suggestions

    /// Returns observations that have crossed the threshold and haven't been dismissed.
    ///
    /// Results are sorted by session count (most observed first) and capped
    /// at ``maxSuggestions``.
    public func suggestable(
        from state: State,
        threshold: Int = PatternTracker.defaultThreshold
    ) -> [Observation] {
        Array(
            state.observations
                .filter { key, obs in
                    obs.sessions.count >= threshold && !state.dismissed.contains(key)
                }
                .map(\.value)
                .sorted { $0.sessions.count > $1.sessions.count }
                .prefix(Self.maxSuggestions)
        )
    }

    // MARK: - Pruning

    /// Maximum number of observations to keep. When exceeded, the least
    /// observed single-session entries are evicted first.
    public static let maxObservations = 200

    /// Removes stale observations: entries seen in only one session that
    /// aren't in the current distillation. Keeps the dictionary bounded.
    ///
    /// Call after `record()` to prevent unbounded growth.
    public func prune(currentKeys: Set<String>) throws {
        var state = load()
        guard state.observations.count > Self.maxObservations else { return }

        // Evict single-session entries not in the current distillation
        let staleKeys = state.observations.filter { key, obs in
            obs.sessions.count == 1 && !currentKeys.contains(key)
        }.map(\.key)

        for key in staleKeys {
            state.observations.removeValue(forKey: key)
            if state.observations.count <= Self.maxObservations { break }
        }

        try save(state)
    }

    // MARK: - Dismissal

    /// Marks a pattern as permanently dismissed.
    public func dismiss(text: String) throws {
        var state = load()
        state.dismissed.insert(Self.normalize(text))
        try save(state)
    }

    /// Checks whether a pattern has been dismissed.
    public func isDismissed(_ text: String) -> Bool {
        load().dismissed.contains(Self.normalize(text))
    }

    // MARK: - Parsing

    /// Normalizes entry text for stable matching across distillation runs.
    ///
    /// Strips leading `- `, trims whitespace, and lowercases.
    public static func normalize(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("- ") {
            t = String(t.dropFirst(2))
        } else if t == "-" {
            return ""
        }
        return t.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Parses distilled markdown output into entries with categories.
    ///
    /// Expects Haiku's standard format: `## Category` headings with `- entry` bullets.
    public static func parseEntries(from markdown: String) -> [(text: String, category: String)] {
        var entries: [(String, String)] = []
        var currentCategory: String?

        for line in markdown.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") {
                currentCategory = String(line.dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("- "), let category = currentCategory {
                let text = String(line.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    entries.append((text, category))
                }
            }
        }

        return entries
    }
}
