import XCTest
@testable import AtelierKit

/// Performance tests verifying that two-file session storage keeps restore
/// time bounded regardless of tool payload size.
///
/// Uses XCTest `measure {}` for wall-clock timing and concrete assertions
/// on data sizes. These tests use 100 tool events with 50KB payloads each
/// (~5MB total) to amplify the difference between lightweight and full decode.
final class SessionPersistencePerformanceTests: XCTestCase {

    // MARK: - Helpers

    private func makeHeavySnapshot(
        toolCount: Int,
        payloadSize: Int,
        sessionId: String = "perf-test"
    ) -> SessionSnapshot {
        let bigString = String(repeating: "x", count: payloadSize)
        var items: [TimelineItem] = []

        for i in 0..<toolCount {
            if i % 3 == 0 {
                items.append(TimelineItem(content: .userMessage(UserMessage(text: "Do something \(i)"))))
            }
            items.append(TimelineItem(content: .toolUse(ToolUseEvent(
                id: "toolu_\(i)",
                name: ["Read", "Bash", "Glob", "Edit"][i % 4],
                inputJSON: "{\"file_path\":\"\(bigString)\"}",
                status: .completed,
                resultOutput: bigString
            ))))
        }

        return SessionSnapshot(sessionId: sessionId, items: items)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Lightweight file is smaller than full snapshot

    func testLightweightFileSizeIsUnder10PercentOfFull() throws {
        let dir = try makeTempDir()
        let persistence = DiskSessionPersistence(baseDirectory: dir)
        let snapshot = makeHeavySnapshot(toolCount: 100, payloadSize: 50_000)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let fullSize = try encoder.encode(snapshot).count

        try persistence.saveImmediately(snapshot)
        let mainSize = try Data(contentsOf: dir.appendingPathComponent("perf-test.json")).count

        let ratio = Double(mainSize) / Double(fullSize)
        XCTAssertLessThan(ratio, 0.10,
            "Lightweight main file should be <10% of full snapshot (\(mainSize / 1024)KB vs \(fullSize / 1024)KB)")
    }

    // MARK: - Lightweight restore is faster than full restore

    func testLightweightRestoreIsFasterThanFull() throws {
        let dir = try makeTempDir()
        let persistence = DiskSessionPersistence(baseDirectory: dir)
        let snapshot = makeHeavySnapshot(toolCount: 100, payloadSize: 50_000)

        // Prepare full data (old approach)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let fullData = try encoder.encode(snapshot)

        // Prepare lightweight data (new approach)
        try persistence.saveImmediately(snapshot)
        let lightweightData = try Data(contentsOf: dir.appendingPathComponent("perf-test.json"))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Warm up decoder
        _ = try decoder.decode(SessionSnapshot.self, from: lightweightData)
        _ = try decoder.decode(SessionSnapshot.self, from: fullData)

        let iterations = 10

        let fullStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = try decoder.decode(SessionSnapshot.self, from: fullData)
        }
        let fullDuration = CFAbsoluteTimeGetCurrent() - fullStart

        let lightStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = try decoder.decode(SessionSnapshot.self, from: lightweightData)
        }
        let lightDuration = CFAbsoluteTimeGetCurrent() - lightStart

        XCTAssertLessThan(lightDuration, fullDuration,
            "Lightweight decode (\(String(format: "%.3f", lightDuration))s) should be faster than full (\(String(format: "%.3f", fullDuration))s)")
    }

    // MARK: - Sidecar round-trip integrity

    func testSidecarContainsAllToolPayloads() throws {
        let dir = try makeTempDir()
        let persistence = DiskSessionPersistence(baseDirectory: dir)
        let toolCount = 50
        let snapshot = makeHeavySnapshot(toolCount: toolCount, payloadSize: 1_000)

        try persistence.saveImmediately(snapshot)

        let sidecarURL = dir.appendingPathComponent("perf-test-payloads.json")
        let sidecarData = try Data(contentsOf: sidecarURL)
        let payloads = try JSONDecoder().decode([String: ToolPayload].self, from: sidecarData)

        XCTAssertEqual(payloads.count, toolCount, "Sidecar should have one entry per tool event")

        for (_, payload) in payloads {
            XCTAssertFalse(payload.inputJSON.isEmpty, "Payload inputJSON should not be empty")
            XCTAssertFalse(payload.resultOutput.isEmpty, "Payload resultOutput should not be empty")
        }
    }

    // MARK: - Lightweight main file has no heavy data

    func testLightweightMainFileHasNoBulkPayloads() throws {
        let dir = try makeTempDir()
        let persistence = DiskSessionPersistence(baseDirectory: dir)
        let snapshot = makeHeavySnapshot(toolCount: 20, payloadSize: 10_000)

        try persistence.saveImmediately(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let mainData = try Data(contentsOf: dir.appendingPathComponent("perf-test.json"))
        let loaded = try decoder.decode(SessionSnapshot.self, from: mainData)

        for item in loaded.items {
            guard case .toolUse(let event) = item.content else { continue }
            XCTAssert(event.inputJSON.isEmpty, "Main file tool should have empty inputJSON")
            XCTAssert(event.resultOutput.isEmpty, "Main file tool should have empty resultOutput")
            // cachedResultSummary must be populated (all test tools have resultOutput)
            XCTAssertFalse(event.cachedResultSummary.isEmpty, "Main file tool should have cached result summary")
            // cachedInputSummary may be empty — depends on tool name vs JSON key match
        }
    }
}
