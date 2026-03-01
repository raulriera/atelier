import Foundation

/// A point-in-time capture of a conversation session.
public struct SessionSnapshot: Sendable, Codable {
    public var sessionId: String
    public var items: [TimelineItem]
    public var savedAt: Date

    public init(sessionId: String, items: [TimelineItem], savedAt: Date = Date()) {
        self.sessionId = sessionId
        self.items = items
        self.savedAt = savedAt
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

/// Persistence contract for saving and restoring conversation sessions.
public protocol SessionPersistence: Sendable {
    func save(_ snapshot: SessionSnapshot) async throws
    func load(id: String) async throws -> SessionSnapshot?
    func loadMostRecent() async throws -> SessionSnapshot?
    func list() async -> [SessionSnapshotMetadata]
    func delete(id: String) async
}

/// Disk-backed session persistence that stores one JSON file per session.
///
/// Files are written to `baseDirectory/{sessionId}.json` using atomic writes.
public actor DiskSessionPersistence: SessionPersistence {
    private let baseDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    /// The default sessions directory inside Application Support.
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Atelier/sessions", isDirectory: true)
    }

    public func save(_ snapshot: SessionSnapshot) throws {
        let manager = FileManager.default
        if !manager.fileExists(atPath: baseDirectory.path) {
            try manager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let fileURL = url(for: snapshot.sessionId)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load(id: String) throws -> SessionSnapshot? {
        let fileURL = url(for: id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionSnapshot.self, from: data)
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
        let fileURL = url(for: id)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func url(for sessionId: String) -> URL {
        baseDirectory.appendingPathComponent("\(sessionId).json")
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
            let sessionId = fileURL.deletingPathExtension().lastPathComponent
            let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return SessionSnapshotMetadata(sessionId: sessionId, savedAt: modDate)
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

    public func load(id: String) -> SessionSnapshot? {
        snapshots[id]
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
