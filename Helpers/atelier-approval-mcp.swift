#!/usr/bin/env swift
//
// atelier-approval-mcp — Minimal MCP server that delegates tool approval
// to the Atelier app via Unix domain socket.
//
// Speaks JSON-RPC 2.0 over stdio. The Claude CLI launches this as a child
// process and calls the `approve` tool when it needs permission to run a tool.
//
// Environment:
//   ATELIER_APPROVAL_SOCKET — path to the Unix domain socket the app listens on
//

import Foundation

// MARK: - JSON-RPC types

struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: AnyCodableValue?
    let method: String
    let params: AnyCodableValue?
}

struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: AnyCodableValue?
    let result: AnyCodableValue?
    let error: JSONRPCError?
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
}

/// A type-erased Codable value for JSON-RPC params/results.
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dict([String: AnyCodableValue])
    case array([AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([String: AnyCodableValue].self) {
            self = .dict(v)
        } else if let v = try? container.decode([AnyCodableValue].self) {
            self = .array(v)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .dict(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var dictValue: [String: AnyCodableValue]? {
        if case .dict(let v) = self { return v }
        return nil
    }
}

// MARK: - Socket communication

struct ApprovalIPCRequest: Codable {
    let id: String
    let toolName: String
    let inputJSON: String
}

struct ApprovalIPCResponse: Codable {
    let behavior: String
    let message: String?
}

// MARK: - Ask User IPC types

struct AskUserIPCOption: Codable {
    let label: String
    let description: String?
}

struct AskUserIPCRequest: Codable {
    let requestType: String  // "ask_user"
    let id: String
    let question: String
    let options: [AskUserIPCOption]
}

struct AskUserIPCResponse: Codable {
    let selectedIndex: Int
    let selectedLabel: String
}

func connectToSocket(path: String) -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = path.utf8CString
    guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
        close(fd)
        return nil
    }
    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
            pathBytes.withUnsafeBufferPointer { src in
                _ = memcpy(dest, src.baseAddress!, src.count)
            }
        }
    }

    let result = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
            connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    guard result == 0 else {
        close(fd)
        return nil
    }
    return fd
}

func sendAndReceive(socketPath: String, request: ApprovalIPCRequest) -> ApprovalIPCResponse? {
    guard let fd = connectToSocket(path: socketPath) else { return nil }
    defer { close(fd) }

    guard var data = try? JSONEncoder().encode(request) else { return nil }
    data.append(contentsOf: "\n".utf8)

    let sent = data.withUnsafeBytes { buffer in
        send(fd, buffer.baseAddress!, buffer.count, 0)
    }
    guard sent == data.count else { return nil }

    // Read response line
    var responseData = Data()
    var byte: UInt8 = 0
    while true {
        let n = recv(fd, &byte, 1, 0)
        guard n > 0 else { break }
        if byte == UInt8(ascii: "\n") { break }
        responseData.append(byte)
    }

    guard !responseData.isEmpty else { return nil }
    return try? JSONDecoder().decode(ApprovalIPCResponse.self, from: responseData)
}

func sendAndReceiveAskUser(socketPath: String, request: AskUserIPCRequest) -> AskUserIPCResponse? {
    guard let fd = connectToSocket(path: socketPath) else { return nil }
    defer { close(fd) }

    guard var data = try? JSONEncoder().encode(request) else { return nil }
    data.append(contentsOf: "\n".utf8)

    let sent = data.withUnsafeBytes { buffer in
        send(fd, buffer.baseAddress!, buffer.count, 0)
    }
    guard sent == data.count else { return nil }

    // Read response line
    var responseData = Data()
    var byte: UInt8 = 0
    while true {
        let n = recv(fd, &byte, 1, 0)
        guard n > 0 else { break }
        if byte == UInt8(ascii: "\n") { break }
        responseData.append(byte)
    }

    guard !responseData.isEmpty else { return nil }
    return try? JSONDecoder().decode(AskUserIPCResponse.self, from: responseData)
}

// MARK: - MCP request handling

func respond(id: AnyCodableValue?, result: AnyCodableValue) {
    let response = JSONRPCResponse(jsonrpc: "2.0", id: id, result: result, error: nil)
    guard let data = try? JSONEncoder().encode(response) else { return }
    var output = data
    output.append(contentsOf: "\n".utf8)
    FileHandle.standardOutput.write(output)
}

func respondError(id: AnyCodableValue?, code: Int, message: String) {
    let response = JSONRPCResponse(
        jsonrpc: "2.0", id: id, result: nil,
        error: JSONRPCError(code: code, message: message)
    )
    guard let data = try? JSONEncoder().encode(response) else { return }
    var output = data
    output.append(contentsOf: "\n".utf8)
    FileHandle.standardOutput.write(output)
}

func handleInitialize(id: AnyCodableValue?) {
    respond(id: id, result: .dict([
        "protocolVersion": .string("2024-11-05"),
        "capabilities": .dict([
            "tools": .dict([:])
        ]),
        "serverInfo": .dict([
            "name": .string("atelier-approval"),
            "version": .string("1.0.0")
        ])
    ]))
}

func handleToolsList(id: AnyCodableValue?) {
    respond(id: id, result: .dict([
        "tools": .array([
            .dict([
                "name": .string("approve"),
                "description": .string("Request approval from the user to use a tool"),
                "inputSchema": .dict([
                    "type": .string("object"),
                    "properties": .dict([
                        "tool_use_id": .dict([
                            "type": .string("string"),
                            "description": .string("Unique identifier for this tool invocation")
                        ]),
                        "tool_name": .dict([
                            "type": .string("string"),
                            "description": .string("The name of the tool requesting approval")
                        ]),
                        "input": .dict([
                            "description": .string("The input for the tool")
                        ])
                    ]),
                    "required": .array([.string("tool_name"), .string("input")])
                ])
            ]),
            .dict([
                "name": .string("ask_user"),
                "description": .string("Ask the user a question with multiple options"),
                "inputSchema": .dict([
                    "type": .string("object"),
                    "properties": .dict([
                        "question": .dict([
                            "type": .string("string"),
                            "description": .string("The question to ask the user")
                        ]),
                        "options": .dict([
                            "type": .string("array"),
                            "description": .string("The available choices"),
                            "items": .dict([
                                "type": .string("object"),
                                "properties": .dict([
                                    "label": .dict([
                                        "type": .string("string"),
                                        "description": .string("Display text for this option")
                                    ]),
                                    "description": .dict([
                                        "type": .string("string"),
                                        "description": .string("Explanation of this option")
                                    ])
                                ]),
                                "required": .array([.string("label")])
                            ])
                        ])
                    ]),
                    "required": .array([.string("question"), .string("options")])
                ])
            ])
        ])
    ]))
}

/// Converts an AnyCodableValue to a JSON string for IPC.
func jsonString(from value: AnyCodableValue) -> String {
    if let s = value.stringValue { return s }
    if let data = try? JSONEncoder().encode(value),
       let s = String(data: data, encoding: .utf8) { return s }
    return "{}"
}

func handleToolsCall(id: AnyCodableValue?, params: AnyCodableValue?, socketPath: String) {
    guard let dict = params?.dictValue,
          let toolNameValue = dict["name"]?.stringValue ?? dict["arguments"]?.dictValue?["tool_name"]?.stringValue else {
        respondError(id: id, code: -32602, message: "Invalid parameters")
        return
    }

    let args = dict["arguments"]?.dictValue ?? [:]

    switch toolNameValue {
    case "ask_user":
        handleAskUserCall(id: id, args: args, socketPath: socketPath)
    default:
        handleApproveCall(id: id, args: args, socketPath: socketPath)
    }
}

func handleApproveCall(id: AnyCodableValue?, args: [String: AnyCodableValue], socketPath: String) {
    guard let toolName = args["tool_name"]?.stringValue else {
        respondError(id: id, code: -32602, message: "Missing tool_name")
        return
    }

    let rawInput = args["input"] ?? .dict([:])
    let inputForIPC = jsonString(from: rawInput)

    let requestId = UUID().uuidString
    let ipcRequest = ApprovalIPCRequest(id: requestId, toolName: toolName, inputJSON: inputForIPC)

    FileHandle.standardError.write(Data("approve: requesting approval for \(toolName)\n".utf8))

    guard let ipcResponse = sendAndReceive(socketPath: socketPath, request: ipcRequest) else {
        FileHandle.standardError.write(Data("approve: socket communication failed\n".utf8))
        respondError(id: id, code: -32603, message: "Failed to communicate with Atelier app")
        return
    }

    FileHandle.standardError.write(Data("approve: got response behavior=\(ipcResponse.behavior)\n".utf8))

    // Build result as AnyCodableValue to avoid JSON escaping issues
    let resultValue: AnyCodableValue
    if ipcResponse.behavior == "allow" {
        // The CLI requires updatedInput as a record. Pass through the original
        // input unchanged since we never modify it.
        resultValue = .dict([
            "behavior": .string("allow"),
            "updatedInput": rawInput
        ])
    } else {
        resultValue = .dict([
            "behavior": .string("deny"),
            "message": .string(ipcResponse.message ?? "User denied the request")
        ])
    }

    // Encode the result dict as a JSON string for the text content block
    let resultText: String
    if let data = try? JSONEncoder().encode(resultValue),
       let str = String(data: data, encoding: .utf8) {
        resultText = str
    } else {
        resultText = "{\"behavior\":\"deny\",\"message\":\"Failed to encode response\"}"
    }

    respond(id: id, result: .dict([
        "content": .array([
            .dict([
                "type": .string("text"),
                "text": .string(resultText)
            ])
        ])
    ]))
}

func handleAskUserCall(id: AnyCodableValue?, args: [String: AnyCodableValue], socketPath: String) {
    guard let question = args["question"]?.stringValue else {
        respondError(id: id, code: -32602, message: "Missing question")
        return
    }

    // Parse options array
    var options: [AskUserIPCOption] = []
    if case .array(let optionValues) = args["options"] {
        for optValue in optionValues {
            if let optDict = optValue.dictValue,
               let label = optDict["label"]?.stringValue {
                let desc = optDict["description"]?.stringValue
                options.append(AskUserIPCOption(label: label, description: desc))
            }
        }
    }

    guard !options.isEmpty else {
        respondError(id: id, code: -32602, message: "Options array is empty")
        return
    }

    let requestId = UUID().uuidString
    let ipcRequest = AskUserIPCRequest(
        requestType: "ask_user",
        id: requestId,
        question: question,
        options: options
    )

    FileHandle.standardError.write(Data("ask_user: asking \"\(question)\" with \(options.count) options\n".utf8))

    guard let ipcResponse = sendAndReceiveAskUser(socketPath: socketPath, request: ipcRequest) else {
        FileHandle.standardError.write(Data("ask_user: socket communication failed\n".utf8))
        respondError(id: id, code: -32603, message: "Failed to communicate with Atelier app")
        return
    }

    FileHandle.standardError.write(Data("ask_user: user selected \"\(ipcResponse.selectedLabel)\"\n".utf8))

    let resultText = ipcResponse.selectedLabel

    respond(id: id, result: .dict([
        "content": .array([
            .dict([
                "type": .string("text"),
                "text": .string(resultText)
            ])
        ])
    ]))
}

// MARK: - Main loop

guard let socketPath = ProcessInfo.processInfo.environment["ATELIER_APPROVAL_SOCKET"] else {
    FileHandle.standardError.write(Data("ATELIER_APPROVAL_SOCKET not set\n".utf8))
    exit(1)
}

while let line = readLine(strippingNewline: true) {
    guard let data = line.data(using: .utf8),
          let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: data) else {
        continue
    }

    switch request.method {
    case "initialize":
        handleInitialize(id: request.id)

    case "notifications/initialized":
        // No response needed for notifications
        break

    case "tools/list":
        handleToolsList(id: request.id)

    case "tools/call":
        handleToolsCall(id: request.id, params: request.params, socketPath: socketPath)

    default:
        respondError(id: request.id, code: -32601, message: "Method not found: \(request.method)")
    }
}
