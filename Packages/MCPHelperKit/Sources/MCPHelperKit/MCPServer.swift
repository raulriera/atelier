import Foundation

/// Maximum characters to return from page content reads.
///
/// Shared across capability helpers that read text content (Safari, Mail, Notes).
public let maxContentLength = 100_000

/// A lightweight MCP server that handles JSON-RPC 2.0 over stdio.
///
/// Encapsulates the boilerplate shared by all Atelier capability helpers:
/// request parsing, tool listing, tool dispatch with `<untrusted_document>`
/// wrapping, error formatting, and the stdin read loop.
///
/// Usage:
/// ```swift
/// import MCPHelperKit
///
/// MCPServer.run(name: "safari", tools: allTools()) { name, args in
///     switch name {
///     case "safari_open_url": ...
///     default: return ("Unknown tool: \(name)", true)
///     }
/// }
/// ```
public enum MCPServer {

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    /// The tool handler closure type.
    ///
    /// - Parameters:
    ///   - name: The tool name from the `tools/call` request.
    ///   - args: The tool arguments dictionary.
    /// - Returns: A tuple of (output string, isError).
    public typealias ToolHandler = (_ name: String, _ args: [String: AnyCodableValue]) -> (String, Bool)

    /// Starts the MCP server, reading JSON-RPC requests from stdin until EOF.
    ///
    /// - Parameters:
    ///   - name: The server name (e.g. "safari", "finder"). Used in logging
    ///     and `<untrusted_document>` source tags.
    ///   - tools: The tool definitions returned by `tools/list`.
    ///   - handler: The closure that handles `tools/call` requests.
    public static func run(
        name: String,
        tools: [ToolDefinition],
        handler: ToolHandler
    ) -> Never {
        while let line = readLine(strippingNewline: true) {
            guard let data = line.data(using: .utf8),
                  let request = try? decoder.decode(JSONRPCRequest.self, from: data) else {
                continue
            }

            switch request.method {
            case "initialize":
                handleInitialize(id: request.id, name: name)

            case "notifications/initialized":
                break

            case "tools/list":
                handleToolsList(id: request.id, tools: tools)

            case "tools/call":
                handleToolsCall(id: request.id, params: request.params, serverName: name, handler: handler)

            default:
                respondError(id: request.id, code: -32601, message: "Method not found: \(request.method)")
            }
        }

        exit(0)
    }

    // MARK: - Request Handlers

    static func handleInitialize(id: AnyCodableValue?, name: String) {
        respond(id: id, result: .dict([
            "protocolVersion": .string("2024-11-05"),
            "capabilities": .dict([
                "tools": .dict([:])
            ]),
            "serverInfo": .dict([
                "name": .string("atelier-\(name)"),
                "version": .string("1.0.0")
            ])
        ]))
    }

    static func handleToolsList(id: AnyCodableValue?, tools: [ToolDefinition]) {
        let toolValues = tools.map { tool -> AnyCodableValue in
            .dict([
                "name": .string(tool.name),
                "description": .string(tool.description),
                "inputSchema": tool.inputSchema
            ])
        }
        respond(id: id, result: .dict([
            "tools": .array(toolValues)
        ]))
    }

    static func handleToolsCall(
        id: AnyCodableValue?,
        params: AnyCodableValue?,
        serverName: String,
        handler: ToolHandler
    ) {
        guard let dict = params?.dictValue,
              let toolName = dict["name"]?.stringValue else {
            respondError(id: id, code: -32602, message: "Invalid parameters: missing tool name")
            return
        }

        let args = dict["arguments"]?.dictValue ?? [:]

        log(serverName, "calling \(toolName)")

        let (output, isError) = handler(toolName, args)

        log(serverName, "\(toolName) -> \(isError ? "error" : "ok")")

        if isError {
            respond(id: id, result: .dict([
                "content": .array([
                    .dict([
                        "type": .string("text"),
                        "text": .string(output)
                    ])
                ]),
                "isError": .bool(true)
            ]))
        } else {
            let wrapped = "<untrusted_document source=\"\(serverName):\(toolName)\">\n\(output)\n</untrusted_document>"
            respond(id: id, result: .dict([
                "content": .array([
                    .dict([
                        "type": .string("text"),
                        "text": .string(wrapped)
                    ])
                ])
            ]))
        }
    }

    // MARK: - Transport

    /// Sends a successful JSON-RPC response.
    public static func respond(id: AnyCodableValue?, result: AnyCodableValue) {
        let response = JSONRPCResponse(jsonrpc: "2.0", id: id, result: result, error: nil)
        guard let data = try? encoder.encode(response) else { return }
        var output = data
        output.append(contentsOf: "\n".utf8)
        FileHandle.standardOutput.write(output)
    }

    /// Sends a JSON-RPC error response.
    public static func respondError(id: AnyCodableValue?, code: Int, message: String) {
        let response = JSONRPCResponse(
            jsonrpc: "2.0", id: id, result: nil,
            error: JSONRPCError(code: code, message: message)
        )
        guard let data = try? encoder.encode(response) else { return }
        var output = data
        output.append(contentsOf: "\n".utf8)
        FileHandle.standardOutput.write(output)
    }

    // MARK: - Logging

    /// Writes a log message to stderr with the server name prefix.
    public static func log(_ serverName: String, _ message: String) {
        FileHandle.standardError.write(Data("\(serverName): \(message)\n".utf8))
    }
}
