import Foundation
import Testing
@testable import AtelierSandbox
@testable import AtelierSecurity

// MARK: - Mocks

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
                from: source, to: destination, underlying: "mock move failure"
            )
        }
    }
}

private final class MockFileOperator: FileOperating, @unchecked Sendable {
    var existingFiles: Set<String> = []
    var trashedURLs: [URL] = []
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

// MARK: - Tests

@Suite("SandboxServiceHandler")
struct SandboxServiceHandlerTests {

    private func makeHandler(
        readData: Data = Data(),
        shouldFailOnRead: Bool = false,
        shouldFailOnWrite: Bool = false,
        shouldFailOnMove: Bool = false,
        existingFiles: Set<String> = []
    ) -> SandboxServiceHandler {
        let coordinator = MockFileCoordinator(
            readData: readData,
            shouldFailOnRead: shouldFailOnRead,
            shouldFailOnWrite: shouldFailOnWrite,
            shouldFailOnMove: shouldFailOnMove
        )
        let fileOp = MockFileOperator()
        fileOp.existingFiles = existingFiles

        return SandboxServiceHandler(
            coordinatedOperator: CoordinatedFileOperator(coordinator: coordinator),
            safeOperator: SafeFileOperator(fileOperator: fileOp)
        )
    }

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

    @Test func readFileDispatchesToCoordinator() async throws {
        let testData = Data("hello".utf8)
        let handler = makeHandler(readData: testData)
        let response = try await callHandler(
            handler,
            request: .readFile(path: "/tmp/test.txt")
        )

        guard case .data(let data) = response else {
            Issue.record("Expected data response")
            return
        }
        #expect(data == testData)
    }

    @Test func writeFileDispatchesToCoordinator() async throws {
        let handler = makeHandler()
        let response = try await callHandler(
            handler,
            request: .writeFile(data: Data("content".utf8), path: "/tmp/out.txt")
        )

        guard case .empty = response else {
            Issue.record("Expected empty response")
            return
        }
    }

    @Test func moveFileDispatchesToCoordinator() async throws {
        let handler = makeHandler()
        let response = try await callHandler(
            handler,
            request: .moveFile(source: "/tmp/a.txt", destination: "/tmp/b.txt")
        )

        guard case .empty = response else {
            Issue.record("Expected empty response")
            return
        }
    }

    @Test func copyFileDispatchesToSafeOperator() async throws {
        let handler = makeHandler(existingFiles: ["/tmp/source.txt"])
        let response = try await callHandler(
            handler,
            request: .copyFile(source: "/tmp/source.txt", destination: "/tmp/dest.txt")
        )

        guard case .empty = response else {
            Issue.record("Expected empty response")
            return
        }
    }

    @Test func trashFileDispatchesToSafeOperator() async throws {
        let handler = makeHandler(existingFiles: ["/tmp/trash.txt"])
        let response = try await callHandler(
            handler,
            request: .trashFile(path: "/tmp/trash.txt")
        )

        guard case .empty = response else {
            Issue.record("Expected empty response")
            return
        }
    }

    @Test func readFileErrorMapsToSandboxError() async {
        let handler = makeHandler(shouldFailOnRead: true)

        do {
            _ = try await callHandler(
                handler,
                request: .readFile(path: "/tmp/fail.txt")
            )
            Issue.record("Expected error")
        } catch is SandboxError {
            // Expected
        } catch {
            Issue.record("Expected SandboxError, got \(error)")
        }
    }

    @Test func copyFileNotFoundReturnsSandboxError() async {
        let handler = makeHandler(existingFiles: [])

        do {
            _ = try await callHandler(
                handler,
                request: .copyFile(
                    source: "/tmp/missing.txt",
                    destination: "/tmp/dest.txt"
                )
            )
            Issue.record("Expected error")
        } catch let error as SandboxError {
            if case .fileNotFound = error {} else {
                Issue.record("Expected fileNotFound, got \(error)")
            }
        } catch {
            Issue.record("Expected SandboxError, got \(error)")
        }
    }

    @Test func trashFileNotFoundReturnsSandboxError() async {
        let handler = makeHandler(existingFiles: [])

        do {
            _ = try await callHandler(
                handler,
                request: .trashFile(path: "/tmp/missing.txt")
            )
            Issue.record("Expected error")
        } catch let error as SandboxError {
            if case .fileNotFound = error {} else {
                Issue.record("Expected fileNotFound, got \(error)")
            }
        } catch {
            Issue.record("Expected SandboxError, got \(error)")
        }
    }

    @Test func listDirectoryReturnsEntries() async throws {
        let handler = makeHandler()
        // Use a directory we know exists
        let response = try await callHandler(
            handler,
            request: .listDirectory(path: "/tmp")
        )

        guard case .listing(let listing) = response else {
            Issue.record("Expected listing response")
            return
        }
        #expect(listing.path == "/tmp")
    }

    @Test func listDirectoryNotFoundReturnsError() async {
        let handler = makeHandler()

        do {
            _ = try await callHandler(
                handler,
                request: .listDirectory(
                    path: "/nonexistent_dir_\(UUID().uuidString)"
                )
            )
            Issue.record("Expected error")
        } catch let error as SandboxError {
            if case .fileNotFound = error {} else {
                Issue.record("Expected fileNotFound, got \(error)")
            }
        } catch {
            Issue.record("Expected SandboxError, got \(error)")
        }
    }

    @Test func fileMetadataReturnsInfo() async throws {
        // Create a temp file to get metadata for
        let tempPath = NSTemporaryDirectory() + "sandbox_test_\(UUID().uuidString).txt"
        FileManager.default.createFile(
            atPath: tempPath,
            contents: Data("test".utf8)
        )
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let handler = makeHandler()
        let response = try await callHandler(
            handler,
            request: .fileMetadata(path: tempPath)
        )

        guard case .metadata(let metadata) = response else {
            Issue.record("Expected metadata response")
            return
        }
        #expect(metadata.path == tempPath)
        #expect(metadata.size == 4)
        #expect(metadata.isDirectory == false)
        #expect(metadata.isReadable == true)
    }

    @Test func fileMetadataNotFoundReturnsError() async {
        let handler = makeHandler()

        do {
            _ = try await callHandler(
                handler,
                request: .fileMetadata(
                    path: "/nonexistent_\(UUID().uuidString).txt"
                )
            )
            Issue.record("Expected error")
        } catch let error as SandboxError {
            if case .fileNotFound = error {} else {
                Issue.record("Expected fileNotFound, got \(error)")
            }
        } catch {
            Issue.record("Expected SandboxError, got \(error)")
        }
    }

    @Test func invalidRequestDataReturnsError() async {
        let handler = makeHandler()
        let badData = Data("not json".utf8)

        let result: (Data?, Data?) = await withCheckedContinuation { continuation in
            handler.performOperation(badData) { responseData, errorData in
                continuation.resume(returning: (responseData, errorData))
            }
        }

        #expect(result.0 == nil)
        #expect(result.1 != nil)
    }
}
