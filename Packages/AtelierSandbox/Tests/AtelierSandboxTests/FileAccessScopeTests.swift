import Foundation
import Testing
@testable import AtelierSandbox

@Suite("FileAccessScope")
struct FileAccessScopeTests {

    // MARK: - requiredScope classification

    @Test func readFileRequiresReadScope() {
        let request = SandboxRequest.readFile(path: "/tmp/file.txt")
        #expect(request.requiredScope == .read)
    }

    @Test func listDirectoryRequiresReadScope() {
        let request = SandboxRequest.listDirectory(path: "/tmp")
        #expect(request.requiredScope == .read)
    }

    @Test func fileMetadataRequiresReadScope() {
        let request = SandboxRequest.fileMetadata(path: "/tmp/file.txt")
        #expect(request.requiredScope == .read)
    }

    @Test func writeFileRequiresWriteScope() {
        let request = SandboxRequest.writeFile(data: Data(), path: "/tmp/file.txt")
        #expect(request.requiredScope == .write)
    }

    @Test func moveFileRequiresWriteScope() {
        let request = SandboxRequest.moveFile(source: "/tmp/a", destination: "/tmp/b")
        #expect(request.requiredScope == .write)
    }

    @Test func copyFileRequiresWriteScope() {
        let request = SandboxRequest.copyFile(source: "/tmp/a", destination: "/tmp/b")
        #expect(request.requiredScope == .write)
    }

    @Test func trashFileRequiresWriteScope() {
        let request = SandboxRequest.trashFile(path: "/tmp/file.txt")
        #expect(request.requiredScope == .write)
    }

    // MARK: - affectedPaths extraction

    @Test func singlePathOperationsReturnOnePath() {
        let cases: [SandboxRequest] = [
            .readFile(path: "/a"),
            .listDirectory(path: "/b"),
            .fileMetadata(path: "/c"),
            .trashFile(path: "/d"),
            .writeFile(data: Data(), path: "/e"),
        ]
        for request in cases {
            #expect(request.affectedPaths.count == 1)
        }
    }

    @Test func moveFileReturnsBothPaths() {
        let request = SandboxRequest.moveFile(
            source: "/tmp/src",
            destination: "/tmp/dst"
        )
        #expect(request.affectedPaths == ["/tmp/src", "/tmp/dst"])
    }

    @Test func copyFileReturnsBothPaths() {
        let request = SandboxRequest.copyFile(
            source: "/data/orig",
            destination: "/data/copy"
        )
        #expect(request.affectedPaths == ["/data/orig", "/data/copy"])
    }
}
