import Foundation
import Testing
@testable import AtelierSecurity

// MARK: - Mock

private struct MockFileCoordinator: FileCoordinating {
    var readData: Data = Data()
    var shouldFailOnRead = false
    var shouldFailOnWrite = false
    var shouldFailOnMove = false

    func coordinateReading(at url: URL) async throws -> Data {
        if shouldFailOnRead {
            throw CoordinatedFileError.readFailed(url, underlying: "mock read failure")
        }
        return readData
    }

    func coordinateWriting(data: Data, to url: URL) async throws {
        if shouldFailOnWrite {
            throw CoordinatedFileError.writeFailed(url, underlying: "mock write failure")
        }
    }

    func coordinateMoving(from source: URL, to destination: URL) async throws {
        if shouldFailOnMove {
            throw CoordinatedFileError.moveFailed(
                from: source,
                to: destination,
                underlying: "mock move failure"
            )
        }
    }
}

@Suite("CoordinatedFileOperator")
struct CoordinatedFileOperatorTests {

    @Test func readReturnsData() async throws {
        let testData = Data("hello world".utf8)
        let mock = MockFileCoordinator(readData: testData)
        let logger = InMemoryAuditLogger()
        let operator_ = CoordinatedFileOperator(coordinator: mock, auditLogger: logger)

        let result = try await operator_.read(at: URL(fileURLWithPath: "/tmp/test.txt"))
        #expect(result == testData)

        let events = await logger.events(category: .fileOperation, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].action == "coordinated-read")
    }

    @Test func writeLogsEvent() async throws {
        let mock = MockFileCoordinator()
        let logger = InMemoryAuditLogger()
        let operator_ = CoordinatedFileOperator(coordinator: mock, auditLogger: logger)

        let data = Data("content".utf8)
        try await operator_.write(data: data, to: URL(fileURLWithPath: "/tmp/out.txt"))

        let events = await logger.events(category: .fileOperation, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].action == "coordinated-write")
        #expect(events[0].detail?.contains("\(data.count)") == true)
    }

    @Test func moveLogsEvent() async throws {
        let mock = MockFileCoordinator()
        let logger = InMemoryAuditLogger()
        let operator_ = CoordinatedFileOperator(coordinator: mock, auditLogger: logger)

        let source = URL(fileURLWithPath: "/tmp/a.txt")
        let dest = URL(fileURLWithPath: "/tmp/b.txt")
        try await operator_.move(from: source, to: dest)

        let events = await logger.events(category: .fileOperation, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].action == "coordinated-move")
        #expect(events[0].subject == source.path)
    }

    @Test func readPropagatesError() async {
        let mock = MockFileCoordinator(shouldFailOnRead: true)
        let operator_ = CoordinatedFileOperator(coordinator: mock)

        do {
            _ = try await operator_.read(at: URL(fileURLWithPath: "/tmp/fail.txt"))
            Issue.record("Expected readFailed error")
        } catch let error as CoordinatedFileError {
            if case .readFailed = error {} else {
                Issue.record("Expected readFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected CoordinatedFileError, got \(error)")
        }
    }

    @Test func writePropagatesError() async {
        let mock = MockFileCoordinator(shouldFailOnWrite: true)
        let operator_ = CoordinatedFileOperator(coordinator: mock)

        do {
            try await operator_.write(data: Data(), to: URL(fileURLWithPath: "/tmp/fail.txt"))
            Issue.record("Expected writeFailed error")
        } catch let error as CoordinatedFileError {
            if case .writeFailed = error {} else {
                Issue.record("Expected writeFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected CoordinatedFileError, got \(error)")
        }
    }

    @Test func movePropagatesError() async {
        let mock = MockFileCoordinator(shouldFailOnMove: true)
        let operator_ = CoordinatedFileOperator(coordinator: mock)

        do {
            try await operator_.move(
                from: URL(fileURLWithPath: "/tmp/a.txt"),
                to: URL(fileURLWithPath: "/tmp/b.txt")
            )
            Issue.record("Expected moveFailed error")
        } catch let error as CoordinatedFileError {
            if case .moveFailed = error {} else {
                Issue.record("Expected moveFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected CoordinatedFileError, got \(error)")
        }
    }
}
