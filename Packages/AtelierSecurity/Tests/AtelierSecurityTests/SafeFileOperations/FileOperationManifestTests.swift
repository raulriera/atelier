import Foundation
import Testing
@testable import AtelierSecurity

@Suite("FileOperationManifest")
struct FileOperationManifestTests {

    @Test func countsByOperationType() {
        let manifest = FileOperationManifest(
            operations: [
                .trash(URL(fileURLWithPath: "/a")),
                .trash(URL(fileURLWithPath: "/b")),
                .move(from: URL(fileURLWithPath: "/c"), to: URL(fileURLWithPath: "/d")),
                .copy(from: URL(fileURLWithPath: "/e"), to: URL(fileURLWithPath: "/f")),
                .rename(from: URL(fileURLWithPath: "/g"), newName: "h"),
            ],
            description: "test manifest"
        )

        #expect(manifest.trashCount == 2)
        #expect(manifest.moveCount == 1)
        #expect(manifest.copyCount == 1)
        #expect(manifest.renameCount == 1)
        #expect(manifest.totalCount == 5)
    }

    @Test func emptyManifest() {
        let manifest = FileOperationManifest(operations: [], description: "empty")
        #expect(manifest.totalCount == 0)
        #expect(manifest.trashCount == 0)
    }
}
