import Foundation
import Testing
@testable import AtelierKit

@Suite("ContextHealth")
struct ContextHealthTests {
    private let manager = FileManager.default

    private func makeTempDir() throws -> URL {
        let url = manager.temporaryDirectory
            .appendingPathComponent("ContextHealthTests-\(UUID().uuidString)")
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func scanEmptyProjectReturnsZeros() throws {
        let dir = try makeTempDir()
        defer { try? manager.removeItem(at: dir) }

        let health = ContextHealth.scan(projectRoot: dir)
        #expect(health.files.isEmpty)
        #expect(health.compactionSnapshotCount == 0)
        #expect(health.latestCompactionDate == nil)
        #expect(health.totalBytes == 0)
        #expect(health.totalTokens == 0)
    }

    @Test func scanFindsMemoryFiles() throws {
        let dir = try makeTempDir()
        defer { try? manager.removeItem(at: dir) }

        let memoryDir = dir.appendingPathComponent(".atelier/memory")
        try manager.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Preferences\n- Dark mode".write(
            to: memoryDir.appendingPathComponent("preferences.md"),
            atomically: true, encoding: .utf8
        )
        try "## Decisions\n- Chose Stripe".write(
            to: memoryDir.appendingPathComponent("decisions.md"),
            atomically: true, encoding: .utf8
        )

        let health = ContextHealth.scan(projectRoot: dir)
        let filenames = health.files.map(\.filename)
        #expect(filenames.contains("preferences.md"))
        #expect(filenames.contains("decisions.md"))
        #expect(health.totalBytes > 0)
        #expect(health.totalTokens > 0)
    }

    @Test func scanClassifiesAlwaysInjectFiles() throws {
        let dir = try makeTempDir()
        defer { try? manager.removeItem(at: dir) }

        let memoryDir = dir.appendingPathComponent(".atelier/memory")
        try manager.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "prefs".write(
            to: memoryDir.appendingPathComponent("preferences.md"),
            atomically: true, encoding: .utf8
        )
        try "decisions".write(
            to: memoryDir.appendingPathComponent("decisions.md"),
            atomically: true, encoding: .utf8
        )

        let health = ContextHealth.scan(projectRoot: dir)
        let prefs = health.files.first { $0.filename == "preferences.md" }
        let decisions = health.files.first { $0.filename == "decisions.md" }
        #expect(prefs?.source == .alwaysInject)
        #expect(decisions?.source == .manifest)
    }

    @Test func scanFindsCompactionSnapshots() throws {
        let dir = try makeTempDir()
        defer { try? manager.removeItem(at: dir) }

        let compactsDir = dir.appendingPathComponent(".atelier/memory/compacts")
        try manager.createDirectory(at: compactsDir, withIntermediateDirectories: true)
        try "snapshot 1".write(
            to: compactsDir.appendingPathComponent("2026-03-01T10-00-00Z.md"),
            atomically: true, encoding: .utf8
        )
        try "snapshot 2".write(
            to: compactsDir.appendingPathComponent("2026-03-02T10-00-00Z.md"),
            atomically: true, encoding: .utf8
        )

        let health = ContextHealth.scan(projectRoot: dir)
        #expect(health.compactionSnapshotCount == 2)
        #expect(health.latestCompactionDate != nil)

        let snapshots = health.files.filter { $0.source == .compactionSnapshot }
        #expect(snapshots.count == 2)
    }

    @Test func scanFindsStructureMap() throws {
        let dir = try makeTempDir()
        defer { try? manager.removeItem(at: dir) }

        let atelierDir = dir.appendingPathComponent(".atelier")
        try manager.createDirectory(at: atelierDir, withIntermediateDirectories: true)
        try "[\"README.md\"]".write(
            to: atelierDir.appendingPathComponent("structure.json"),
            atomically: true, encoding: .utf8
        )

        let health = ContextHealth.scan(projectRoot: dir)
        let structureFile = health.files.first { $0.source == .structureMap }
        #expect(structureFile != nil)
        #expect(structureFile?.filename == "structure.json")
    }

    @Test func alwaysInjectedTokensExcludesManifestFiles() throws {
        let dir = try makeTempDir()
        defer { try? manager.removeItem(at: dir) }

        let memoryDir = dir.appendingPathComponent(".atelier/memory")
        try manager.createDirectory(at: memoryDir, withIntermediateDirectories: true)

        let bigContent = String(repeating: "x", count: 400) // ~100 tokens
        try bigContent.write(
            to: memoryDir.appendingPathComponent("preferences.md"),
            atomically: true, encoding: .utf8
        )
        try bigContent.write(
            to: memoryDir.appendingPathComponent("decisions.md"),
            atomically: true, encoding: .utf8
        )

        let health = ContextHealth.scan(projectRoot: dir)
        // preferences.md is always-inject, decisions.md is manifest
        #expect(health.alwaysInjectedTokens == 100)
        #expect(health.totalTokens == 200)
    }
}
