import Foundation
import Testing
@testable import AtelierSandbox

@Suite("SandboxRequest")
struct SandboxRequestTests {

    @Test func readFileEncodes() throws {
        let request = SandboxRequest.readFile(path: "/tmp/test.txt")
        let data = try XPCCoder.encode(request)
        let decoded = try XPCCoder.decode(SandboxRequest.self, from: data)

        guard case .readFile(let path) = decoded else {
            Issue.record("Expected readFile case")
            return
        }
        #expect(path == "/tmp/test.txt")
    }

    @Test func writeFileEncodes() throws {
        let content = Data("hello world".utf8)
        let request = SandboxRequest.writeFile(data: content, path: "/tmp/out.txt")
        let data = try XPCCoder.encode(request)
        let decoded = try XPCCoder.decode(SandboxRequest.self, from: data)

        guard case .writeFile(let decodedData, let path) = decoded else {
            Issue.record("Expected writeFile case")
            return
        }
        #expect(decodedData == content)
        #expect(path == "/tmp/out.txt")
    }

    @Test func moveFileEncodes() throws {
        let request = SandboxRequest.moveFile(
            source: "/tmp/a.txt",
            destination: "/tmp/b.txt"
        )
        let data = try XPCCoder.encode(request)
        let decoded = try XPCCoder.decode(SandboxRequest.self, from: data)

        guard case .moveFile(let source, let dest) = decoded else {
            Issue.record("Expected moveFile case")
            return
        }
        #expect(source == "/tmp/a.txt")
        #expect(dest == "/tmp/b.txt")
    }

    @Test func copyFileEncodes() throws {
        let request = SandboxRequest.copyFile(
            source: "/tmp/c.txt",
            destination: "/tmp/d.txt"
        )
        let data = try XPCCoder.encode(request)
        let decoded = try XPCCoder.decode(SandboxRequest.self, from: data)

        guard case .copyFile(let source, let dest) = decoded else {
            Issue.record("Expected copyFile case")
            return
        }
        #expect(source == "/tmp/c.txt")
        #expect(dest == "/tmp/d.txt")
    }

    @Test func trashFileEncodes() throws {
        let request = SandboxRequest.trashFile(path: "/tmp/trash.txt")
        let data = try XPCCoder.encode(request)
        let decoded = try XPCCoder.decode(SandboxRequest.self, from: data)

        guard case .trashFile(let path) = decoded else {
            Issue.record("Expected trashFile case")
            return
        }
        #expect(path == "/tmp/trash.txt")
    }

    @Test func listDirectoryEncodes() throws {
        let request = SandboxRequest.listDirectory(path: "/tmp")
        let data = try XPCCoder.encode(request)
        let decoded = try XPCCoder.decode(SandboxRequest.self, from: data)

        guard case .listDirectory(let path) = decoded else {
            Issue.record("Expected listDirectory case")
            return
        }
        #expect(path == "/tmp")
    }

    @Test func fileMetadataEncodes() throws {
        let request = SandboxRequest.fileMetadata(path: "/tmp/file.txt")
        let data = try XPCCoder.encode(request)
        let decoded = try XPCCoder.decode(SandboxRequest.self, from: data)

        guard case .fileMetadata(let path) = decoded else {
            Issue.record("Expected fileMetadata case")
            return
        }
        #expect(path == "/tmp/file.txt")
    }
}
