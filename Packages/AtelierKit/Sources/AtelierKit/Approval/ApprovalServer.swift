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
    private var askUserContinuations: [String: CheckedContinuation<AskUserIPCResponse, Never>] = [:]
    private var requestContinuation: AsyncStream<ApprovalRequest>.Continuation?
    private var askUserRequestContinuation: AsyncStream<AskUserIPCRequest>.Continuation?

    /// Publishes incoming approval requests as they arrive from the MCP binary.
    public let requests: AsyncStream<ApprovalRequest>

    /// Publishes incoming ask-user requests as they arrive from the MCP binary.
    public let askUserRequests: AsyncStream<AskUserIPCRequest>

    public init() {
        let path = "/tmp/atelier-approval-\(UUID().uuidString).sock"
        self.socketPath = path

        var continuation: AsyncStream<ApprovalRequest>.Continuation!
        self.requests = AsyncStream { continuation = $0 }
        self.requestContinuation = continuation

        var askContinuation: AsyncStream<AskUserIPCRequest>.Continuation!
        self.askUserRequests = AsyncStream { askContinuation = $0 }
        self.askUserRequestContinuation = askContinuation
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
        askUserRequestContinuation?.finish()
        askUserRequestContinuation = nil

        Self.logger.info("Stopped")
    }

    /// Resumes the continuation for the given request, sending the decision back to the MCP binary.
    public func respond(requestId: String, decision: ApprovalDecision) {
        guard let continuation = continuations.removeValue(forKey: requestId) else { return }
        continuation.resume(returning: decision)
    }

    /// Resumes the continuation for the given ask-user request with the user's selection.
    public func respondAskUser(requestId: String, selectedIndex: Int, selectedLabel: String) {
        guard let continuation = askUserContinuations.removeValue(forKey: requestId) else { return }
        continuation.resume(returning: AskUserIPCResponse(selectedIndex: selectedIndex, selectedLabel: selectedLabel))
    }

    /// Denies all pending approvals and dismisses pending ask-user requests — used during app shutdown.
    public func denyAllPending() {
        let pending = continuations
        continuations.removeAll()
        for (_, continuation) in pending {
            continuation.resume(returning: .deny(reason: "App closed"))
        }

        let pendingAskUser = askUserContinuations
        askUserContinuations.removeAll()
        for (_, continuation) in pendingAskUser {
            continuation.resume(returning: AskUserIPCResponse(selectedIndex: -1, selectedLabel: "Dismissed"))
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

        // Prevent SIGPIPE when the CLI closes the connection before we respond
        // (e.g. user stopped generation while an ask-user card was pending).
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        // Read one JSON line
        guard let requestData = readLine(from: fd) else {
            Self.logger.warning("Failed to read request from connection")
            return
        }

        let decoder = JSONDecoder()

        // Peek at requestType to determine which flow to use
        let envelope = try? decoder.decode(IPCRequestEnvelope.self, from: requestData)

        if envelope?.requestType == "ask_user" {
            await handleAskUserConnection(fd: fd, data: requestData, decoder: decoder)
        } else {
            await handleApprovalConnection(fd: fd, data: requestData, decoder: decoder)
        }
    }

    private func handleApprovalConnection(fd: Int32, data: Data, decoder: JSONDecoder) async {
        guard let request = try? decoder.decode(ApprovalRequest.self, from: data) else {
            Self.logger.warning("Failed to decode approval request from connection")
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
        case .allow, .allowForSession:
            response = ApprovalResponse(behavior: "allow", message: nil)
        case .deny(let reason):
            response = ApprovalResponse(behavior: "deny", message: reason)
        }

        sendResponse(fd: fd, response)
    }

    private func handleAskUserConnection(fd: Int32, data: Data, decoder: JSONDecoder) async {
        guard let request = try? decoder.decode(AskUserIPCRequest.self, from: data) else {
            Self.logger.warning("Failed to decode ask-user request from connection")
            return
        }

        Self.logger.debug("Received ask-user request: \(request.id, privacy: .public)")

        // Publish request to the UI
        askUserRequestContinuation?.yield(request)

        // Wait for user selection
        let response = await withCheckedContinuation { (continuation: CheckedContinuation<AskUserIPCResponse, Never>) in
            askUserContinuations[request.id] = continuation
        }

        sendResponse(fd: fd, response)
    }

    private func sendResponse<T: Encodable>(fd: Int32, _ response: T) {
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
