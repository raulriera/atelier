import Foundation

/// Client-side actor wrapping `NSXPCConnection` for sandbox file operations.
///
/// Conforms to `SandboxServiceProtocol` for a type-safe async API.
/// Lazily connects on first use and auto-reconnects on interruption.
public actor SandboxClient: SandboxServiceProtocol {
    private let serviceName: String
    private var connection: NSXPCConnection?

    public init(serviceName: String = "com.raulriera.Atelier.SandboxService") {
        self.serviceName = serviceName
    }

    public func readFile(at path: String) async throws -> Data {
        let response = try await send(.readFile(path: path))
        guard case .data(let data) = response else {
            throw SandboxError.decodingFailed("Expected data response")
        }
        return data
    }

    public func writeFile(data: Data, to path: String) async throws {
        let response = try await send(.writeFile(data: data, path: path))
        guard case .empty = response else {
            throw SandboxError.decodingFailed("Expected empty response")
        }
    }

    public func moveFile(from source: String, to destination: String) async throws {
        let response = try await send(
            .moveFile(source: source, destination: destination)
        )
        guard case .empty = response else {
            throw SandboxError.decodingFailed("Expected empty response")
        }
    }

    public func copyFile(from source: String, to destination: String) async throws {
        let response = try await send(
            .copyFile(source: source, destination: destination)
        )
        guard case .empty = response else {
            throw SandboxError.decodingFailed("Expected empty response")
        }
    }

    public func trashFile(at path: String) async throws {
        let response = try await send(.trashFile(path: path))
        guard case .empty = response else {
            throw SandboxError.decodingFailed("Expected empty response")
        }
    }

    public func listDirectory(at path: String) async throws -> DirectoryListing {
        let response = try await send(.listDirectory(path: path))
        guard case .listing(let listing) = response else {
            throw SandboxError.decodingFailed("Expected listing response")
        }
        return listing
    }

    public func fileMetadata(at path: String) async throws -> FileMetadata {
        let response = try await send(.fileMetadata(path: path))
        guard case .metadata(let metadata) = response else {
            throw SandboxError.decodingFailed("Expected metadata response")
        }
        return metadata
    }

    // MARK: - Connection Management

    private func send(_ request: SandboxRequest) async throws -> SandboxResponse {
        let requestData = try XPCCoder.encode(request)
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.performOperation(requestData) { responseData, errorData in
                if let errorData {
                    if let error = try? XPCCoder.decode(
                        SandboxError.self,
                        from: errorData
                    ) {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(
                            throwing: SandboxError.decodingFailed(
                                "Failed to decode error response"
                            )
                        )
                    }
                    return
                }

                guard let responseData else {
                    continuation.resume(
                        throwing: SandboxError.decodingFailed("No response data")
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

    private func getProxy() throws -> any SandboxXPCProtocol {
        let conn = ensureConnection()
        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
            // Connection error — will reconnect on next call
            _ = error
        }) as? any SandboxXPCProtocol else {
            throw SandboxError.connectionInterrupted
        }
        return proxy
    }

    private func ensureConnection() -> NSXPCConnection {
        if let existing = connection {
            return existing
        }

        let conn = NSXPCConnection(serviceName: serviceName)
        conn.remoteObjectInterface = NSXPCInterface(
            with: SandboxXPCProtocol.self
        )

        conn.interruptionHandler = { [weak self] in
            Task { [weak self] in
                await self?.handleInterruption()
            }
        }

        conn.invalidationHandler = { [weak self] in
            Task { [weak self] in
                await self?.handleInvalidation()
            }
        }

        conn.resume()
        connection = conn
        return conn
    }

    private func handleInterruption() {
        // Connection interrupted — will reconnect on next use
        connection = nil
    }

    private func handleInvalidation() {
        connection = nil
    }
}
