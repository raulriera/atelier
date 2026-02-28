import Foundation
import Testing
@testable import AtelierSandbox

@Suite("SandboxResponse")
struct SandboxResponseTests {

    @Test func dataResponseEncodes() throws {
        let content = Data("file content".utf8)
        let response = SandboxResponse.data(content)
        let encoded = try XPCCoder.encode(response)
        let decoded = try XPCCoder.decode(SandboxResponse.self, from: encoded)

        guard case .data(let data) = decoded else {
            Issue.record("Expected data case")
            return
        }
        #expect(data == content)
    }

    @Test func emptyResponseEncodes() throws {
        let response = SandboxResponse.empty
        let encoded = try XPCCoder.encode(response)
        let decoded = try XPCCoder.decode(SandboxResponse.self, from: encoded)

        guard case .empty = decoded else {
            Issue.record("Expected empty case")
            return
        }
    }

    @Test func listingResponseEncodes() throws {
        let listing = DirectoryListing(
            path: "/tmp",
            entries: [
                .init(name: "readme.md", isDirectory: false),
                .init(name: "src", isDirectory: true),
            ]
        )
        let response = SandboxResponse.listing(listing)
        let encoded = try XPCCoder.encode(response)
        let decoded = try XPCCoder.decode(SandboxResponse.self, from: encoded)

        guard case .listing(let result) = decoded else {
            Issue.record("Expected listing case")
            return
        }
        #expect(result == listing)
    }

    @Test func metadataResponseEncodes() throws {
        let metadata = FileMetadata(
            path: "/tmp/test.txt",
            size: 2048,
            creationDate: Date(timeIntervalSince1970: 1000000),
            modificationDate: Date(timeIntervalSince1970: 2000000),
            isDirectory: false,
            isReadable: true,
            isWritable: true,
            posixPermissions: 0o755
        )
        let response = SandboxResponse.metadata(metadata)
        let encoded = try XPCCoder.encode(response)
        let decoded = try XPCCoder.decode(SandboxResponse.self, from: encoded)

        guard case .metadata(let result) = decoded else {
            Issue.record("Expected metadata case")
            return
        }
        #expect(result == metadata)
    }

    @Test func directoryListingEquality() {
        let a = DirectoryListing(
            path: "/tmp",
            entries: [.init(name: "a.txt", isDirectory: false)]
        )
        let b = DirectoryListing(
            path: "/tmp",
            entries: [.init(name: "a.txt", isDirectory: false)]
        )
        let c = DirectoryListing(
            path: "/var",
            entries: [.init(name: "a.txt", isDirectory: false)]
        )

        #expect(a == b)
        #expect(a != c)
    }

    @Test func fileMetadataEquality() {
        let date = Date(timeIntervalSince1970: 1000000)
        let a = FileMetadata(
            path: "/tmp/f.txt",
            size: 100,
            creationDate: date,
            modificationDate: date,
            isDirectory: false,
            isReadable: true,
            isWritable: false,
            posixPermissions: 0o644
        )
        let b = FileMetadata(
            path: "/tmp/f.txt",
            size: 100,
            creationDate: date,
            modificationDate: date,
            isDirectory: false,
            isReadable: true,
            isWritable: false,
            posixPermissions: 0o644
        )
        let c = FileMetadata(
            path: "/tmp/f.txt",
            size: 200,
            creationDate: date,
            modificationDate: date,
            isDirectory: false,
            isReadable: true,
            isWritable: false,
            posixPermissions: 0o644
        )

        #expect(a == b)
        #expect(a != c)
    }
}
