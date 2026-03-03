import Foundation

/// A point-in-time capture of a conversation session.
public struct SessionSnapshot: Sendable, Codable {
    public var sessionId: String
    public var items: [TimelineItem]
    public var savedAt: Date
    public var wasInterrupted: Bool

    public init(sessionId: String, items: [TimelineItem], savedAt: Date = Date(), wasInterrupted: Bool = false) {
        self.sessionId = sessionId
        self.items = items
        self.savedAt = savedAt
        self.wasInterrupted = wasInterrupted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        // Decode items fault-tolerantly: skip individual items that fail
        // to decode rather than losing the entire session.
        let lossy = try container.decode([LossyDecodable<TimelineItem>].self, forKey: .items)
        items = lossy.compactMap(\.value)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        wasInterrupted = try container.decodeIfPresent(Bool.self, forKey: .wasInterrupted) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId, items, savedAt, wasInterrupted
    }
}

/// Lightweight metadata for listing saved sessions without loading items.
public struct SessionSnapshotMetadata: Sendable {
    public var sessionId: String
    public var savedAt: Date

    public init(sessionId: String, savedAt: Date) {
        self.sessionId = sessionId
        self.savedAt = savedAt
    }
}

/// Full tool payload stored in the sidecar file, keyed by tool event ID.
public struct ToolPayload: Sendable, Codable {
    public var inputJSON: String
    public var resultOutput: String

    public init(inputJSON: String, resultOutput: String) {
        self.inputJSON = inputJSON
        self.resultOutput = resultOutput
    }
}

/// Persistence contract for saving and restoring conversation sessions.
public protocol SessionPersistence: Sendable {
    func save(_ snapshot: SessionSnapshot) async throws
    func saveImmediately(_ snapshot: SessionSnapshot) throws
    func load(id: String) async throws -> SessionSnapshot?
    func loadMostRecent() async throws -> SessionSnapshot?
    func list() async -> [SessionSnapshotMetadata]
    func delete(id: String) async
    func loadToolPayloads(sessionId: String) async throws -> [String: ToolPayload]
}

/// Disk-backed session persistence that stores one JSON file per session.
///
/// Files are written to `baseDirectory/{sessionId}.json` using atomic writes.
/// Heavy tool payloads are stored in a sidecar `{sessionId}-payloads.json`.
public actor DiskSessionPersistence: SessionPersistence {
    private let baseDirectory: URL
    private var payloadCache: [String: [String: ToolPayload]] = [:]

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    /// The default sessions directory inside Application Support.
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Atelier/sessions", isDirectory: true)
    }

    public func save(_ snapshot: SessionSnapshot) throws {
        try writeSnapshot(snapshot)
    }

    /// Synchronous save that bypasses actor isolation for use during app termination.
    ///
    /// Safe because `baseDirectory` is immutable (`let`) and file writes are atomic.
    nonisolated public func saveImmediately(_ snapshot: SessionSnapshot) throws {
        try writeSnapshot(snapshot)
    }

    private nonisolated func writeSnapshot(_ snapshot: SessionSnapshot) throws {
        let manager = FileManager.default
        if !manager.fileExists(atPath: baseDirectory.path) {
            try manager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }

        let (lightweight, payloads) = separatePayloads(snapshot)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let mainData = try encoder.encode(lightweight)
        let mainURL = baseDirectory.appendingPathComponent("\(snapshot.sessionId).json")
        try mainData.write(to: mainURL, options: .atomic)

        let payloadURL = baseDirectory.appendingPathComponent("\(snapshot.sessionId)-payloads.json")
        if payloads.isEmpty {
            try? manager.removeItem(at: payloadURL)
        } else {
            let payloadData = try encoder.encode(payloads)
            try payloadData.write(to: payloadURL, options: .atomic)
        }
    }

    /// Separates heavy tool payloads from the snapshot.
    ///
    /// Returns a lightweight snapshot (tool events with empty `inputJSON`/`resultOutput`
    /// but populated `cachedInputSummary`/`cachedResultSummary`) and a dictionary of
    /// full payloads keyed by tool event ID.
    private nonisolated func separatePayloads(_ snapshot: SessionSnapshot) -> (SessionSnapshot, [String: ToolPayload]) {
        var lightweight = snapshot
        var payloads: [String: ToolPayload] = [:]

        for index in lightweight.items.indices {
            guard case .toolUse(var event) = lightweight.items[index].content else { continue }

            let hasPayload = !event.inputJSON.isEmpty || !event.resultOutput.isEmpty
            guard hasPayload else { continue }

            payloads[event.id] = ToolPayload(inputJSON: event.inputJSON, resultOutput: event.resultOutput)

            // Precompute summaries before stripping payloads
            event.cachedInputSummary = event.inputSummary
            event.cachedResultSummary = event.resultSummary

            event.inputJSON = ""
            event.resultOutput = ""

            lightweight.items[index].content = .toolUse(event)
        }

        return (lightweight, payloads)
    }

    public func load(id: String) throws -> SessionSnapshot? {
        let fileURL = url(for: id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionSnapshot.self, from: data)
    }

    public func loadToolPayloads(sessionId: String) throws -> [String: ToolPayload] {
        if let cached = payloadCache[sessionId] { return cached }

        let fileURL = baseDirectory.appendingPathComponent("\(sessionId)-payloads.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let payloads = try decoder.decode([String: ToolPayload].self, from: data)
        payloadCache[sessionId] = payloads
        return payloads
    }

    public func loadMostRecent() throws -> SessionSnapshot? {
        let metadata = listMetadata()
        guard let newest = metadata.max(by: { $0.savedAt < $1.savedAt }) else { return nil }
        return try load(id: newest.sessionId)
    }

    public func list() -> [SessionSnapshotMetadata] {
        listMetadata()
    }

    public func delete(id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
        try? FileManager.default.removeItem(at: payloadURL(for: id))
        payloadCache.removeValue(forKey: id)
    }

    private func url(for sessionId: String) -> URL {
        baseDirectory.appendingPathComponent("\(sessionId).json")
    }

    private func payloadURL(for sessionId: String) -> URL {
        baseDirectory.appendingPathComponent("\(sessionId)-payloads.json")
    }

    private func listMetadata() -> [SessionSnapshotMetadata] {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return files.compactMap { fileURL -> SessionSnapshotMetadata? in
            guard fileURL.pathExtension == "json" else { return nil }
            let name = fileURL.deletingPathExtension().lastPathComponent
            // Skip sidecar files
            guard !name.hasSuffix("-payloads") else { return nil }
            let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return SessionSnapshotMetadata(sessionId: name, savedAt: modDate)
        }
    }
}

/// In-memory session persistence for testing.
public actor InMemorySessionPersistence: SessionPersistence {
    private var snapshots: [String: SessionSnapshot] = [:]

    public init() {}

    public func save(_ snapshot: SessionSnapshot) {
        snapshots[snapshot.sessionId] = snapshot
    }

    /// No-op for in-memory persistence — tests don't exercise app termination paths.
    nonisolated public func saveImmediately(_ snapshot: SessionSnapshot) {}

    public func load(id: String) -> SessionSnapshot? {
        snapshots[id]
    }

    public func loadToolPayloads(sessionId: String) -> [String: ToolPayload] {
        guard let snapshot = snapshots[sessionId] else { return [:] }
        var payloads: [String: ToolPayload] = [:]
        for item in snapshot.items {
            guard case .toolUse(let event) = item.content else { continue }
            let hasPayload = !event.inputJSON.isEmpty || !event.resultOutput.isEmpty
            guard hasPayload else { continue }
            payloads[event.id] = ToolPayload(inputJSON: event.inputJSON, resultOutput: event.resultOutput)
        }
        return payloads
    }

    public func loadMostRecent() -> SessionSnapshot? {
        snapshots.values.max(by: { $0.savedAt < $1.savedAt })
    }

    public func list() -> [SessionSnapshotMetadata] {
        snapshots.values.map {
            SessionSnapshotMetadata(sessionId: $0.sessionId, savedAt: $0.savedAt)
        }
    }

    public func delete(id: String) {
        snapshots[id] = nil
    }
}
