import Foundation
import os

/// Listens on a Unix domain socket for tool approval requests from the MCP server binary.
///
/// Each connection reads one JSON-line request, suspends until the user decides,
/// then writes one JSON-line response. The server publishes incoming requests via
/// an `AsyncStream` so the UI can present approval cards.
public actor ApprovalServer {
    private static let logger = Logger(subsystem: "com.atelier.kit", category: "ApprovalServer")

    /// The filesystem path to the Unix domain socket.
    public let socketPath: String

    private var serverFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var continuations: [String: CheckedContinuation<ApprovalDecision, Never>] = [:]
    private var requestContinuation: AsyncStream<ApprovalRequest>.Continuation?

    /// Publishes incoming approval requests as they arrive from the MCP binary.
    public let requests: AsyncStream<ApprovalRequest>

    public init() {
        let path = "/tmp/atelier-approval-\(UUID().uuidString).sock"
        self.socketPath = path

        var continuation: AsyncStream<ApprovalRequest>.Continuation!
        self.requests = AsyncStream { continuation = $0 }
        self.requestContinuation = continuation
    }

    /// Creates the Unix socket, binds, and begins accepting connections.
    public func start() throws {
        // Clean up stale socket file
        unlink(socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ApprovalServerError.socketCreationFailed(errno)
        }

        // Set non-blocking so accept() never blocks the thread
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw ApprovalServerError.pathTooLong
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                pathBytes.withUnsafeBufferPointer { src in
                    _ = memcpy(dest, src.baseAddress!, src.count)
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw ApprovalServerError.bindFailed(errno)
        }

        guard listen(fd, 8) == 0 else {
            close(fd)
            unlink(socketPath)
            throw ApprovalServerError.listenFailed(errno)
        }

        serverFD = fd
        Self.logger.info("Listening on \(self.socketPath, privacy: .public)")

        // Use GCD dispatch source for non-blocking accept — cancels cleanly
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else { return }
            Task { await self.handleConnection(clientFD) }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        acceptSource = source
    }

    /// Closes the socket and cleans up the socket file.
    public func stop() {
        if let source = acceptSource {
            source.cancel()
            acceptSource = nil
            serverFD = -1  // fd closed by cancel handler
        } else if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        unlink(socketPath)

        requestContinuation?.finish()
        requestContinuation = nil

        Self.logger.info("Stopped")
    }

    /// Resumes the continuation for the given request, sending the decision back to the MCP binary.
    public func respond(requestId: String, decision: ApprovalDecision) {
        guard let continuation = continuations.removeValue(forKey: requestId) else { return }
        continuation.resume(returning: decision)
    }

    /// Denies all pending approvals — used during app shutdown.
    public func denyAllPending() {
        let pending = continuations
        continuations.removeAll()
        for (_, continuation) in pending {
            continuation.resume(returning: .deny(reason: "App closed"))
        }
    }

    // MARK: - Private

    private func handleConnection(_ fd: Int32) async {
        defer { close(fd) }

        // On macOS, accept() inherits O_NONBLOCK from the listening socket.
        // Set the client fd to blocking so recv/send work reliably.
        let flags = fcntl(fd, F_GETFL)
        if flags & O_NONBLOCK != 0 {
            _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        }

        // Read one JSON line
        guard let requestData = readLine(from: fd),
              let request = try? JSONDecoder().decode(ApprovalRequest.self, from: requestData) else {
            Self.logger.warning("Failed to read approval request from connection")
            return
        }

        Self.logger.debug("Received approval request: \(request.id, privacy: .public) tool=\(request.toolName, privacy: .public)")

        // Publish request to the UI
        requestContinuation?.yield(request)

        // Wait for user decision
        let decision = await withCheckedContinuation { (continuation: CheckedContinuation<ApprovalDecision, Never>) in
            continuations[request.id] = continuation
        }

        // Send response
        let response: ApprovalResponse
        switch decision {
        case .allow:
            response = ApprovalResponse(behavior: "allow", message: nil)
        case .deny(let reason):
            response = ApprovalResponse(behavior: "deny", message: reason)
        }

        if let responseData = try? JSONEncoder().encode(response) {
            var data = responseData
            data.append(contentsOf: "\n".utf8)
            data.withUnsafeBytes { buffer in
                _ = send(fd, buffer.baseAddress!, buffer.count, 0)
            }
        }
    }

    /// Reads bytes from a file descriptor until a newline is found.
    private nonisolated func readLine(from fd: Int32) -> Data? {
        var data = Data()
        var byte: UInt8 = 0
        while true {
            let bytesRead = recv(fd, &byte, 1, 0)
            guard bytesRead > 0 else { return nil }
            if byte == UInt8(ascii: "\n") { break }
            data.append(byte)
        }
        return data.isEmpty ? nil : data
    }
}

public enum ApprovalServerError: Error {
    case socketCreationFailed(Int32)
    case pathTooLong
    case bindFailed(Int32)
    case listenFailed(Int32)
}
