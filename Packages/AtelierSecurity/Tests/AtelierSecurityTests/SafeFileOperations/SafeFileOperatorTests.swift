import Foundation
import Testing
@testable import AtelierSecurity

// MARK: - Mock

private final class MockFileOperator: FileOperating, @unchecked Sendable {
    var existingFiles: Set<String> = []
    var trashedURLs: [URL] = []
    var movedPairs: [(URL, URL)] = []
    var copiedPairs: [(URL, URL)] = []

    func trashItem(at url: URL) throws -> URL {
        guard existingFiles.contains(url.path) else {
            throw NSError(domain: "test", code: 1)
        }
        existingFiles.remove(url.path)
        let trashURL = URL(fileURLWithPath: "/.Trash/\(url.lastPathComponent)")
        trashedURLs.append(trashURL)
        return trashURL
    }

    func moveItem(from source: URL, to destination: URL) throws {
        guard existingFiles.contains(source.path) else {
            throw NSError(domain: "test", code: 2)
        }
        existingFiles.remove(source.path)
        existingFiles.insert(destination.path)
        movedPairs.append((source, destination))
    }

    func copyItem(from source: URL, to destination: URL) throws {
        guard existingFiles.contains(source.path) else {
            throw NSError(domain: "test", code: 3)
        }
        existingFiles.insert(destination.path)
        copiedPairs.append((source, destination))
    }

    func fileExists(at url: URL) -> Bool {
        existingFiles.contains(url.path)
    }
}

@Suite("SafeFileOperator")
struct SafeFileOperatorTests {

    @Test func trashOperationSucceeds() async {
        let mock = MockFileOperator()
        mock.existingFiles = ["/tmp/file.txt"]
        let logger = InMemoryAuditLogger()
        let operator_ = SafeFileOperator(fileOperator: mock, auditLogger: logger)

        let result = await operator_.execute(
            operation: .trash(URL(fileURLWithPath: "/tmp/file.txt"))
        )

        if case .success(let record) = result {
            #expect(record.resultURL?.lastPathComponent == "file.txt")
        } else {
            Issue.record("Expected success")
        }

        let events = await logger.events(category: .fileOperation, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].action == "trash")
    }

    @Test func trashFailsForMissingFile() async {
        let mock = MockFileOperator()
        let operator_ = SafeFileOperator(fileOperator: mock)

        let result = await operator_.execute(
            operation: .trash(URL(fileURLWithPath: "/nonexistent"))
        )

        if case .failure(_, let error) = result {
            if case .fileNotFound = error {} else {
                Issue.record("Expected fileNotFound error")
            }
        } else {
            Issue.record("Expected failure")
        }
    }

    @Test func moveOperationSucceeds() async {
        let mock = MockFileOperator()
        mock.existingFiles = ["/tmp/source.txt"]
        let operator_ = SafeFileOperator(fileOperator: mock)

        let from = URL(fileURLWithPath: "/tmp/source.txt")
        let to = URL(fileURLWithPath: "/tmp/dest.txt")
        let result = await operator_.execute(operation: .move(from: from, to: to))

        if case .success(let record) = result {
            #expect(record.resultURL == to)
        } else {
            Issue.record("Expected success")
        }
    }

    @Test func moveFailsWhenDestinationExists() async {
        let mock = MockFileOperator()
        mock.existingFiles = ["/tmp/source.txt", "/tmp/dest.txt"]
        let operator_ = SafeFileOperator(fileOperator: mock)

        let result = await operator_.execute(
            operation: .move(
                from: URL(fileURLWithPath: "/tmp/source.txt"),
                to: URL(fileURLWithPath: "/tmp/dest.txt")
            )
        )

        if case .failure(_, let error) = result {
            if case .destinationExists = error {} else {
                Issue.record("Expected destinationExists error")
            }
        } else {
            Issue.record("Expected failure")
        }
    }

    @Test func copyOperationSucceeds() async {
        let mock = MockFileOperator()
        mock.existingFiles = ["/tmp/original.txt"]
        let operator_ = SafeFileOperator(fileOperator: mock)

        let from = URL(fileURLWithPath: "/tmp/original.txt")
        let to = URL(fileURLWithPath: "/tmp/copy.txt")
        let result = await operator_.execute(operation: .copy(from: from, to: to))

        if case .success(let record) = result {
            #expect(record.resultURL == to)
        } else {
            Issue.record("Expected success")
        }
    }

    @Test func renameOperationSucceeds() async {
        let mock = MockFileOperator()
        mock.existingFiles = ["/tmp/old.txt"]
        let operator_ = SafeFileOperator(fileOperator: mock)

        let result = await operator_.execute(
            operation: .rename(from: URL(fileURLWithPath: "/tmp/old.txt"), newName: "new.txt")
        )

        if case .success(let record) = result {
            #expect(record.resultURL?.lastPathComponent == "new.txt")
        } else {
            Issue.record("Expected success")
        }
    }

    @Test func executeManifestReturnsResultsForAll() async {
        let mock = MockFileOperator()
        mock.existingFiles = ["/tmp/a.txt", "/tmp/b.txt"]
        let operator_ = SafeFileOperator(fileOperator: mock)

        let manifest = operator_.plan(
            operations: [
                .trash(URL(fileURLWithPath: "/tmp/a.txt")),
                .trash(URL(fileURLWithPath: "/tmp/b.txt")),
                .trash(URL(fileURLWithPath: "/tmp/missing.txt")),
            ],
            description: "batch test"
        )

        let results = await operator_.execute(manifest: manifest)
        #expect(results.count == 3)

        // First two succeed, third fails
        if case .success = results[0] {} else { Issue.record("Expected success for a.txt") }
        if case .success = results[1] {} else { Issue.record("Expected success for b.txt") }
        if case .failure = results[2] {} else { Issue.record("Expected failure for missing.txt") }
    }
}
