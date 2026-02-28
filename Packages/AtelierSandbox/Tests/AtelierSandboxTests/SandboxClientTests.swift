import Foundation
import Testing
@testable import AtelierSandbox

// MARK: - Mock

/// In-memory mock implementing `SandboxServiceProtocol` for client dispatch tests.
private actor MockSandboxService: SandboxServiceProtocol {
    var storedData: [String: Data] = [:]
    var directories: [String: [DirectoryListing.Entry]] = [:]
    var metadataStore: [String: FileMetadata] = [:]
    var lastOperation: String?

    func readFile(at path: String) async throws -> Data {
        lastOperation = "readFile"
        guard let data = storedData[path] else {
            throw SandboxError.fileNotFound(path)
        }
        return data
    }

    func writeFile(data: Data, to path: String) async throws {
        lastOperation = "writeFile"
        storedData[path] = data
    }

    func moveFile(from source: String, to destination: String) async throws {
        lastOperation = "moveFile"
        guard let data = storedData[source] else {
            throw SandboxError.fileNotFound(source)
        }
        storedData.removeValue(forKey: source)
        storedData[destination] = data
    }

    func copyFile(from source: String, to destination: String) async throws {
        lastOperation = "copyFile"
        guard let data = storedData[source] else {
            throw SandboxError.fileNotFound(source)
        }
        storedData[destination] = data
    }

    func trashFile(at path: String) async throws {
        lastOperation = "trashFile"
        guard storedData.removeValue(forKey: path) != nil else {
            throw SandboxError.fileNotFound(path)
        }
    }

    func listDirectory(at path: String) async throws -> DirectoryListing {
        lastOperation = "listDirectory"
        guard let entries = directories[path] else {
            throw SandboxError.fileNotFound(path)
        }
        return DirectoryListing(path: path, entries: entries)
    }

    func fileMetadata(at path: String) async throws -> FileMetadata {
        lastOperation = "fileMetadata"
        guard let metadata = metadataStore[path] else {
            throw SandboxError.fileNotFound(path)
        }
        return metadata
    }
}

// MARK: - Tests

@Suite("SandboxClient dispatch")
struct SandboxClientTests {

    @Test func readFileReturnsData() async throws {
        let mock = MockSandboxService()
        await mock.setData(Data("hello".utf8), for: "/tmp/test.txt")

        let data = try await mock.readFile(at: "/tmp/test.txt")
        #expect(data == Data("hello".utf8))
        #expect(await mock.lastOperation == "readFile")
    }

    @Test func readFileMissingThrows() async {
        let mock = MockSandboxService()

        do {
            _ = try await mock.readFile(at: "/tmp/missing.txt")
            Issue.record("Expected error")
        } catch let error as SandboxError {
            if case .fileNotFound(let path) = error {
                #expect(path == "/tmp/missing.txt")
            } else {
                Issue.record("Expected fileNotFound")
            }
        } catch {
            Issue.record("Expected SandboxError")
        }
    }

    @Test func writeFileStoresData() async throws {
        let mock = MockSandboxService()
        let content = Data("content".utf8)

        try await mock.writeFile(data: content, to: "/tmp/out.txt")
        let stored = await mock.storedData["/tmp/out.txt"]
        #expect(stored == content)
        #expect(await mock.lastOperation == "writeFile")
    }

    @Test func moveFileTransfersData() async throws {
        let mock = MockSandboxService()
        await mock.setData(Data("data".utf8), for: "/tmp/a.txt")

        try await mock.moveFile(from: "/tmp/a.txt", to: "/tmp/b.txt")
        let source = await mock.storedData["/tmp/a.txt"]
        let dest = await mock.storedData["/tmp/b.txt"]
        #expect(source == nil)
        #expect(dest == Data("data".utf8))
    }

    @Test func copyFileDuplicatesData() async throws {
        let mock = MockSandboxService()
        await mock.setData(Data("data".utf8), for: "/tmp/a.txt")

        try await mock.copyFile(from: "/tmp/a.txt", to: "/tmp/b.txt")
        let source = await mock.storedData["/tmp/a.txt"]
        let dest = await mock.storedData["/tmp/b.txt"]
        #expect(source == Data("data".utf8))
        #expect(dest == Data("data".utf8))
    }

    @Test func trashFileRemovesData() async throws {
        let mock = MockSandboxService()
        await mock.setData(Data("data".utf8), for: "/tmp/trash.txt")

        try await mock.trashFile(at: "/tmp/trash.txt")
        let stored = await mock.storedData["/tmp/trash.txt"]
        #expect(stored == nil)
    }

    @Test func listDirectoryReturnsEntries() async throws {
        let mock = MockSandboxService()
        let entries: [DirectoryListing.Entry] = [
            .init(name: "file.txt", isDirectory: false),
            .init(name: "subdir", isDirectory: true),
        ]
        await mock.setDirectoryEntries(entries, for: "/tmp")

        let listing = try await mock.listDirectory(at: "/tmp")
        #expect(listing.path == "/tmp")
        #expect(listing.entries.count == 2)
        #expect(listing.entries[0].name == "file.txt")
        #expect(listing.entries[1].isDirectory == true)
    }

    @Test func fileMetadataReturnsInfo() async throws {
        let mock = MockSandboxService()
        let metadata = FileMetadata(
            path: "/tmp/test.txt",
            size: 1024,
            creationDate: nil,
            modificationDate: nil,
            isDirectory: false,
            isReadable: true,
            isWritable: true,
            posixPermissions: 0o644
        )
        await mock.setMetadata(metadata, for: "/tmp/test.txt")

        let result = try await mock.fileMetadata(at: "/tmp/test.txt")
        #expect(result == metadata)
    }

    @Test func protocolConformanceCompiles() {
        // Verify SandboxClient conforms to SandboxServiceProtocol at compile time
        let client: any SandboxServiceProtocol = SandboxClient(serviceName: "test")
        _ = client
    }
}

// MARK: - Mock Helpers

extension MockSandboxService {
    func setData(_ data: Data, for path: String) {
        storedData[path] = data
    }

    func setDirectoryEntries(
        _ entries: [DirectoryListing.Entry],
        for path: String
    ) {
        directories[path] = entries
    }

    func setMetadata(_ metadata: FileMetadata, for path: String) {
        metadataStore[path] = metadata
    }
}
