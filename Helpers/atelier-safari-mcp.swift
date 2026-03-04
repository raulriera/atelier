#!/usr/bin/env swift
//
// atelier-safari-mcp — MCP server that controls Safari
// via JXA (JavaScript for Automation) through osascript.
//
// Speaks JSON-RPC 2.0 over stdio. The Claude CLI launches this as a child
// process and discovers the tools via `tools/list`.
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

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var dictValue: [String: AnyCodableValue]? {
        if case .dict(let v) = self { return v }
        return nil
    }
}

// MARK: - JXA Execution

func executeJXA(_ script: String) -> (output: String, error: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-l", "JavaScript", "-e", script]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ("", "Failed to launch osascript: \(error.localizedDescription)", 1)
    }

    let output = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let errOutput = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (output.trimmingCharacters(in: .whitespacesAndNewlines),
            errOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            process.terminationStatus)
}

/// Escapes a Swift string for safe embedding inside a JXA string literal.
func jxaEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
     .replacingOccurrences(of: "\n", with: "\\n")
     .replacingOccurrences(of: "\r", with: "\\r")
     .replacingOccurrences(of: "\t", with: "\\t")
}

// MARK: - Safari JXA Helpers

/// Builds a JXA expression to reference a tab, defaulting to the active tab.
func jxaTabSelector(windowIndex: Int?, tabIndex: Int?) -> String {
    if let w = windowIndex, let t = tabIndex {
        return "app.windows[\(w - 1)].tabs[\(t - 1)]"
    } else if let w = windowIndex {
        return "app.windows[\(w - 1)].currentTab()"
    } else if let t = tabIndex {
        return "app.windows[0].tabs[\(t - 1)]"
    } else {
        return "app.windows[0].currentTab()"
    }
}

/// Builds a JXA script that opens a URL in a new tab (or new window).
func jxaOpenURL(_ url: String, inNewWindow: Bool) -> String {
    let safeURL = jxaEscape(url)
    if inNewWindow {
        return """
        var app = Application("Safari");
        app.activate();
        var doc = app.Document();
        app.documents.push(doc);
        doc.url = "\(safeURL)";
        """
    } else {
        return """
        var app = Application("Safari");
        app.activate();
        if (app.windows.length === 0) {
            var doc = app.Document();
            app.documents.push(doc);
            doc.url = "\(safeURL)";
        } else {
            var win = app.windows[0];
            var tab = app.Tab();
            win.tabs.push(tab);
            tab.url = "\(safeURL)";
            win.currentTab = tab;
        }
        """
    }
}

/// Checks if an error message indicates that JavaScript from Apple Events is disabled.
func isJavaScriptNotAllowedError(_ message: String) -> Bool {
    message.localizedCaseInsensitiveContains("not allowed")
}

let javaScriptNotAllowedMessage = "Error: JavaScript from Apple Events is not allowed. Enable it in Safari > Develop > Allow JavaScript from Apple Events."

/// Maximum characters to return from page content reads.
let maxContentLength = 100_000

// MARK: - Tool Definitions

struct ToolDefinition {
    let name: String
    let description: String
    let inputSchema: AnyCodableValue
}

func allTools() -> [ToolDefinition] {
    [
        ToolDefinition(
            name: "safari_open_url",
            description: "Open a URL in Safari. Opens in a new tab by default, or a new window if specified.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "url": .dict([
                        "type": .string("string"),
                        "description": .string("The URL to open")
                    ]),
                    "newWindow": .dict([
                        "type": .string("boolean"),
                        "description": .string("Open in a new window instead of a new tab. Defaults to false.")
                    ])
                ]),
                "required": .array([.string("url")])
            ])
        ),
        ToolDefinition(
            name: "safari_list_tabs",
            description: "List all open tabs across all Safari windows. Returns window index, tab index, title, and URL for each tab.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([:])
            ])
        ),
        ToolDefinition(
            name: "safari_get_tab_content",
            description: "Read the title, URL, and plain-text body of a Safari tab. Defaults to the active tab if no indices are given. Requires 'Allow JavaScript from Apple Events' in Safari's Develop menu.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "windowIndex": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based window index. Defaults to the frontmost window.")
                    ]),
                    "tabIndex": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based tab index. Defaults to the current tab of the window.")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "safari_execute_javascript",
            description: "Run JavaScript in a Safari tab and return the result. Can be used to fill forms, click buttons, or extract data. Requires 'Allow JavaScript from Apple Events' in Safari's Develop menu.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "javascript": .dict([
                        "type": .string("string"),
                        "description": .string("The JavaScript code to execute in the tab")
                    ]),
                    "windowIndex": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based window index. Defaults to the frontmost window.")
                    ]),
                    "tabIndex": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based tab index. Defaults to the current tab of the window.")
                    ])
                ]),
                "required": .array([.string("javascript")])
            ])
        ),
        ToolDefinition(
            name: "safari_search",
            description: "Search the web using Safari. Opens a Google search for the given query in a new tab.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "query": .dict([
                        "type": .string("string"),
                        "description": .string("The search query")
                    ])
                ]),
                "required": .array([.string("query")])
            ])
        ),
        ToolDefinition(
            name: "safari_close_tab",
            description: "Close a specific tab in Safari.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "windowIndex": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based window index")
                    ]),
                    "tabIndex": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based tab index")
                    ])
                ]),
                "required": .array([.string("windowIndex"), .string("tabIndex")])
            ])
        ),
    ]
}

// MARK: - Tool Handlers

func handleToolCall(name: String, args: [String: AnyCodableValue]) -> (String, Bool) {
    switch name {
    case "safari_open_url":
        guard let url = args["url"]?.stringValue else {
            return ("Missing required parameter: url", true)
        }
        let newWindow = args["newWindow"]?.boolValue ?? false
        let label = newWindow ? "new window" : "new tab"
        let script = jxaOpenURL(url, inNewWindow: newWindow) + """
        "Opened \(jxaEscape(url)) in a \(label)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error opening URL: \(result.error)", true)
        }
        return (result.output, false)

    case "safari_list_tabs":
        let script = """
        var app = Application("Safari");
        var results = [];
        var wins = app.windows();
        for (var w = 0; w < wins.length; w++) {
            var tabs = wins[w].tabs();
            for (var t = 0; t < tabs.length; t++) {
                results.push("Window " + (w+1) + ", Tab " + (t+1) + ": " + tabs[t].name() + " — " + tabs[t].url());
            }
        }
        results.length > 0 ? results.join("\\n") : "No tabs open";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error listing tabs: \(result.error)", true)
        }
        return (result.output, false)

    case "safari_get_tab_content":
        let tabSelector = jxaTabSelector(
            windowIndex: args["windowIndex"]?.intValue,
            tabIndex: args["tabIndex"]?.intValue
        )
        let script = """
        var app = Application("Safari");
        var tab = \(tabSelector);
        var title = tab.name();
        var url = tab.url();
        var body = "";
        try {
            body = app.doJavaScript("document.body.innerText", {in: tab});
            if (body.length > \(maxContentLength)) {
                body = body.substring(0, \(maxContentLength)) + "\\n... (content truncated)";
            }
        } catch(e) {
            body = "Error reading page content: " + e.message + ". Make sure 'Allow JavaScript from Apple Events' is enabled in Safari's Develop menu.";
        }
        "Title: " + title + "\\nURL: " + url + "\\n\\n" + body;
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            if isJavaScriptNotAllowedError(result.error) {
                return (javaScriptNotAllowedMessage, true)
            }
            return ("Error reading tab content: \(result.error)", true)
        }
        return (result.output, false)

    case "safari_execute_javascript":
        guard let javascript = args["javascript"]?.stringValue else {
            return ("Missing required parameter: javascript", true)
        }
        let tabSelector = jxaTabSelector(
            windowIndex: args["windowIndex"]?.intValue,
            tabIndex: args["tabIndex"]?.intValue
        )
        let safeJS = jxaEscape(javascript)
        let script = """
        var app = Application("Safari");
        var tab = \(tabSelector);
        try {
            var result = app.doJavaScript("\(safeJS)", {in: tab});
            result !== undefined && result !== null ? String(result) : "JavaScript executed successfully (no return value)";
        } catch(e) {
            "Error executing JavaScript: " + e.message;
        }
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            if isJavaScriptNotAllowedError(result.error) {
                return (javaScriptNotAllowedMessage, true)
            }
            return ("Error executing JavaScript: \(result.error)", true)
        }
        return (result.output, false)

    case "safari_search":
        guard let query = args["query"]?.stringValue else {
            return ("Missing required parameter: query", true)
        }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return ("Failed to encode search query", true)
        }
        let searchURL = "https://www.google.com/search?q=\(encoded)"
        let script = jxaOpenURL(searchURL, inNewWindow: false) + """
        "Searching for: \(jxaEscape(query))";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error performing search: \(result.error)", true)
        }
        return (result.output, false)

    case "safari_close_tab":
        guard let winIdx = args["windowIndex"]?.intValue,
              let tabIdx = args["tabIndex"]?.intValue else {
            return ("Missing required parameters: windowIndex, tabIndex", true)
        }
        let script = """
        var app = Application("Safari");
        var tab = app.windows[\(winIdx - 1)].tabs[\(tabIdx - 1)];
        var name = tab.name();
        tab.close();
        "Closed tab: " + name;
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error closing tab: \(result.error)", true)
        }
        return (result.output, false)

    default:
        return ("Unknown tool: \(name)", true)
    }
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
            "name": .string("atelier-safari"),
            "version": .string("1.0.0")
        ])
    ]))
}

func handleToolsList(id: AnyCodableValue?) {
    let tools = allTools().map { tool -> AnyCodableValue in
        .dict([
            "name": .string(tool.name),
            "description": .string(tool.description),
            "inputSchema": tool.inputSchema
        ])
    }
    respond(id: id, result: .dict([
        "tools": .array(tools)
    ]))
}

func handleToolsCall(id: AnyCodableValue?, params: AnyCodableValue?) {
    guard let dict = params?.dictValue,
          let toolName = dict["name"]?.stringValue else {
        respondError(id: id, code: -32602, message: "Invalid parameters: missing tool name")
        return
    }

    let args = dict["arguments"]?.dictValue ?? [:]

    FileHandle.standardError.write(Data("safari: calling \(toolName)\n".utf8))

    let (output, isError) = handleToolCall(name: toolName, args: args)

    FileHandle.standardError.write(Data("safari: \(toolName) -> \(isError ? "error" : "ok")\n".utf8))

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
        respond(id: id, result: .dict([
            "content": .array([
                .dict([
                    "type": .string("text"),
                    "text": .string(output)
                ])
            ])
        ]))
    }
}

// MARK: - Main loop

while let line = readLine(strippingNewline: true) {
    guard let data = line.data(using: .utf8),
          let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: data) else {
        continue
    }

    switch request.method {
    case "initialize":
        handleInitialize(id: request.id)

    case "notifications/initialized":
        break

    case "tools/list":
        handleToolsList(id: request.id)

    case "tools/call":
        handleToolsCall(id: request.id, params: request.params)

    default:
        respondError(id: request.id, code: -32601, message: "Method not found: \(request.method)")
    }
}
