import Foundation
import Testing
@testable import AtelierSandbox

@Suite("XPCCoder")
struct XPCCoderTests {

    @Test func roundTripsRequest() throws {
        let requests: [SandboxRequest] = [
            .readFile(path: "/tmp/test.txt"),
            .writeFile(data: Data("hello".utf8), path: "/tmp/out.txt"),
            .moveFile(source: "/tmp/a.txt", destination: "/tmp/b.txt"),
            .copyFile(source: "/tmp/c.txt", destination: "/tmp/d.txt"),
            .trashFile(path: "/tmp/trash.txt"),
            .listDirectory(path: "/tmp"),
            .fileMetadata(path: "/tmp/file.txt"),
        ]

        for request in requests {
            let data = try XPCCoder.encode(request)
            let decoded = try XPCCoder.decode(SandboxRequest.self, from: data)
            #expect(matchesRequest(request, decoded))
        }
    }

    @Test func roundTripsResponse() throws {
        let responses: [SandboxResponse] = [
            .data(Data("content".utf8)),
            .empty,
            .listing(DirectoryListing(path: "/tmp", entries: [
                .init(name: "file.txt", isDirectory: false),
                .init(name: "subdir", isDirectory: true),
            ])),
            .metadata(FileMetadata(
                path: "/tmp/file.txt",
                size: 1024,
                creationDate: nil,
                modificationDate: nil,
                isDirectory: false,
                isReadable: true,
                isWritable: false,
                posixPermissions: 0o644
            )),
        ]

        for response in responses {
            let data = try XPCCoder.encode(response)
            let decoded = try XPCCoder.decode(SandboxResponse.self, from: data)
            #expect(matchesResponse(response, decoded))
        }
    }

    @Test func roundTripsError() throws {
        let errors: [SandboxError] = [
            .fileNotFound("/tmp/missing.txt"),
            .permissionDenied("/tmp/secret.txt"),
            .operationFailed("something went wrong"),
            .encodingFailed("bad data"),
            .decodingFailed("corrupt"),
            .connectionInterrupted,
        ]

        for error in errors {
            let data = try XPCCoder.encode(error)
            let decoded = try XPCCoder.decode(SandboxError.self, from: data)
            #expect(matchesError(error, decoded))
        }
    }

    @Test func decodeInvalidDataThrows() {
        let badData = Data("not json".utf8)
        #expect(throws: SandboxError.self) {
            _ = try XPCCoder.decode(SandboxRequest.self, from: badData)
        }
    }

    // MARK: - Helpers

    private func matchesRequest(
        _ lhs: SandboxRequest,
        _ rhs: SandboxRequest
    ) -> Bool {
        switch (lhs, rhs) {
        case (.readFile(let a), .readFile(let b)):
            return a == b
        case (.writeFile(let d1, let p1), .writeFile(let d2, let p2)):
            return d1 == d2 && p1 == p2
        case (.moveFile(let s1, let d1), .moveFile(let s2, let d2)):
            return s1 == s2 && d1 == d2
        case (.copyFile(let s1, let d1), .copyFile(let s2, let d2)):
            return s1 == s2 && d1 == d2
        case (.trashFile(let a), .trashFile(let b)):
            return a == b
        case (.listDirectory(let a), .listDirectory(let b)):
            return a == b
        case (.fileMetadata(let a), .fileMetadata(let b)):
            return a == b
        default:
            return false
        }
    }

    private func matchesResponse(
        _ lhs: SandboxResponse,
        _ rhs: SandboxResponse
    ) -> Bool {
        switch (lhs, rhs) {
        case (.data(let a), .data(let b)):
            return a == b
        case (.empty, .empty):
            return true
        case (.listing(let a), .listing(let b)):
            return a == b
        case (.metadata(let a), .metadata(let b)):
            return a == b
        default:
            return false
        }
    }

    private func matchesError(
        _ lhs: SandboxError,
        _ rhs: SandboxError
    ) -> Bool {
        switch (lhs, rhs) {
        case (.fileNotFound(let a), .fileNotFound(let b)):
            return a == b
        case (.permissionDenied(let a), .permissionDenied(let b)):
            return a == b
        case (.operationFailed(let a), .operationFailed(let b)):
            return a == b
        case (.encodingFailed(let a), .encodingFailed(let b)):
            return a == b
        case (.decodingFailed(let a), .decodingFailed(let b)):
            return a == b
        case (.connectionInterrupted, .connectionInterrupted):
            return true
        default:
            return false
        }
    }
}
