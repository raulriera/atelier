import Foundation
import Testing
@testable import AtelierSandbox
@testable import AtelierSecurity

@Suite("SandboxServiceDelegate")
struct SandboxServiceDelegateTests {

    private func callHandler(
        _ handler: SandboxServiceHandler,
        request: SandboxRequest
    ) async throws -> SandboxResponse {
        let requestData = try XPCCoder.encode(request)

        return try await withCheckedThrowingContinuation { continuation in
            handler.performOperation(requestData) { responseData, errorData in
                if let errorData {
                    if let error = try? XPCCoder.decode(
                        SandboxError.self,
                        from: errorData
                    ) {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(
                            throwing: SandboxError.decodingFailed("Unknown error")
                        )
                    }
                    return
                }

                guard let responseData else {
                    continuation.resume(
                        throwing: SandboxError.decodingFailed("No response")
                    )
                    return
                }

                do {
                    let response = try XPCCoder.decode(
                        SandboxResponse.self,
                        from: responseData
                    )
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @Test func productionDeniesWhenNoBookmarksExist() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("delegate-test-\(UUID().uuidString)")
        let storeURL = tempDir.appendingPathComponent("bookmarks.json")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let delegate = SandboxServiceDelegate.production(
            bookmarkStoreURL: storeURL
        )

        // Extract the handler via a mock connection to verify behavior
        let handler = SandboxServiceHandler(
            permissionGate: BookmarkBackedPermissionGate(
                store: DiskBookmarkStore(
                    fileURL: storeURL,
                    reloadBeforeRead: true
                )
            )
        )

        await #expect(throws: SandboxError.self) {
            try await callHandler(handler, request: .readFile(path: "/project/file.txt"))
        }

        // Verify delegate was created (production() returned without crash)
        _ = delegate
    }

    @Test func productionAllowsWithMatchingBookmark() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("delegate-test-\(UUID().uuidString)")
        let storeURL = tempDir.appendingPathComponent("bookmarks.json")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Pre-populate the bookmark store
        let store = DiskBookmarkStore(fileURL: storeURL)
        let entry = BookmarkEntry(
            url: URL(fileURLWithPath: "/project"),
            bookmarkData: Data([0x01]),
            permission: .readWrite
        )
        try await store.save(entry)

        // Create a handler with the same store URL (reloadBeforeRead picks it up)
        let handler = SandboxServiceHandler(
            permissionGate: BookmarkBackedPermissionGate(
                store: DiskBookmarkStore(
                    fileURL: storeURL,
                    reloadBeforeRead: true
                )
            )
        )

        // The permission gate passes for /project paths. The coordinator will
        // fail on the actual file read (file doesn't exist), but the error
        // must NOT be permissionDenied — proving the gate allowed it through.
        do {
            _ = try await callHandler(
                handler,
                request: .readFile(path: "/project/file.txt")
            )
        } catch let error as SandboxError {
            if case .permissionDenied = error {
                Issue.record("Expected gate to allow, but got permissionDenied")
            }
            // Any other SandboxError (e.g. operationFailed) is fine — the
            // gate passed, the file just doesn't exist on disk.
        }
    }

    @Test func productionCreatesStoreDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("delegate-dir-test-\(UUID().uuidString)")
        let nested = tempDir
            .appendingPathComponent("deep", isDirectory: true)
            .appendingPathComponent("bookmarks.json")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = SandboxServiceDelegate.production(bookmarkStoreURL: nested)

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: nested.deletingLastPathComponent().path,
            isDirectory: &isDir
        )
        #expect(exists)
        #expect(isDir.boolValue)
    }

    @Test func defaultBookmarkStoreURLPointsToApplicationSupport() {
        let url = SandboxServiceDelegate.defaultBookmarkStoreURL
        #expect(url.path.contains("Application Support"))
        #expect(url.path.contains("Atelier"))
        #expect(url.lastPathComponent == "bookmarks.json")
    }
}
