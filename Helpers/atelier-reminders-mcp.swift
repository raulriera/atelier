#!/usr/bin/env swift
//
// atelier-reminders-mcp — MCP server that controls Reminders.app
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

// MARK: - Tool Definitions

struct ToolDefinition {
    let name: String
    let description: String
    let inputSchema: AnyCodableValue
}

func allTools() -> [ToolDefinition] {
    [
        // Read group
        ToolDefinition(
            name: "reminders_list_lists",
            description: "List all reminder lists in the Reminders app.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([:])
            ])
        ),
        ToolDefinition(
            name: "reminders_list_reminders",
            description: "List reminders in a specific list. Shows title, due date, priority, completion status, and notes. Returns incomplete reminders by default.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "list": .dict([
                        "type": .string("string"),
                        "description": .string("The name of the reminder list. If omitted, uses the default list.")
                    ]),
                    "includeCompleted": .dict([
                        "type": .string("boolean"),
                        "description": .string("Include completed reminders. Defaults to false.")
                    ]),
                    "limit": .dict([
                        "type": .string("integer"),
                        "description": .string("Maximum number of reminders to return. Defaults to 50.")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "reminders_search",
            description: "Search reminders by name or body text across all lists.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "query": .dict([
                        "type": .string("string"),
                        "description": .string("Search query to match against reminder name and body")
                    ]),
                    "limit": .dict([
                        "type": .string("integer"),
                        "description": .string("Maximum number of results. Defaults to 25.")
                    ])
                ]),
                "required": .array([.string("query")])
            ])
        ),

        // Create group
        ToolDefinition(
            name: "reminders_create",
            description: "Create a new reminder. Returns the created reminder's details.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "name": .dict([
                        "type": .string("string"),
                        "description": .string("Title of the reminder")
                    ]),
                    "list": .dict([
                        "type": .string("string"),
                        "description": .string("Name of the list to add it to. Uses the default list if omitted.")
                    ]),
                    "notes": .dict([
                        "type": .string("string"),
                        "description": .string("Additional notes/body for the reminder")
                    ]),
                    "dueDate": .dict([
                        "type": .string("string"),
                        "description": .string("Due date in ISO 8601 format (e.g. \"2026-03-15\" or \"2026-03-15T14:00:00\"). If only a date is given, the reminder is due at start of day.")
                    ]),
                    "priority": .dict([
                        "type": .string("integer"),
                        "description": .string("Priority: 0 = none, 1 = high, 5 = medium, 9 = low")
                    ])
                ]),
                "required": .array([.string("name")])
            ])
        ),

        // Manage group
        ToolDefinition(
            name: "reminders_complete",
            description: "Mark a reminder as completed or uncompleted.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "name": .dict([
                        "type": .string("string"),
                        "description": .string("The exact name of the reminder to complete")
                    ]),
                    "list": .dict([
                        "type": .string("string"),
                        "description": .string("The list containing the reminder. Searches all lists if omitted.")
                    ]),
                    "completed": .dict([
                        "type": .string("boolean"),
                        "description": .string("Set to true to mark complete, false to uncomplete. Defaults to true.")
                    ])
                ]),
                "required": .array([.string("name")])
            ])
        ),
        ToolDefinition(
            name: "reminders_delete",
            description: "Delete a reminder by name.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "name": .dict([
                        "type": .string("string"),
                        "description": .string("The exact name of the reminder to delete")
                    ]),
                    "list": .dict([
                        "type": .string("string"),
                        "description": .string("The list containing the reminder. Searches all lists if omitted.")
                    ])
                ]),
                "required": .array([.string("name")])
            ])
        ),
    ]
}

// MARK: - Tool Handlers

func handleToolCall(name: String, args: [String: AnyCodableValue]) -> (String, Bool) {
    switch name {
    case "reminders_list_lists":
        let script = """
        var app = Application("Reminders");
        var lists = app.lists();
        var results = [];
        for (var i = 0; i < lists.length; i++) {
            var count = lists[i].reminders.whose({completed: false})().length;
            results.push(lists[i].name() + " (" + count + " incomplete)");
        }
        results.length > 0 ? results.join("\\n") : "No reminder lists found";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error listing reminder lists: \(result.error)", true)
        }
        return (result.output, false)

    case "reminders_list_reminders":
        let limit = args["limit"]?.intValue ?? 50
        let includeCompleted = args["includeCompleted"]?.boolValue ?? false
        let listSelector: String
        if let list = args["list"]?.stringValue {
            listSelector = "app.lists.byName(\"\(jxaEscape(list))\")"
        } else {
            listSelector = "app.defaultList()"
        }
        let filterClause = includeCompleted ? "" : ".whose({completed: false})"
        let script = """
        var app = Application("Reminders");
        var list = \(listSelector);
        var reminders = list.reminders\(filterClause)();
        var limit = \(limit);
        var results = [];
        for (var i = 0; i < Math.min(reminders.length, limit); i++) {
            var r = reminders[i];
            var line = r.name();
            var due = r.dueDate();
            if (due) {
                line += " | due: " + due.toISOString();
            }
            var p = r.priority();
            if (p > 0) {
                var pLabel = p === 1 ? "high" : (p === 5 ? "medium" : "low");
                line += " | priority: " + pLabel;
            }
            if (r.completed()) {
                line += " | completed";
            }
            var body = r.body();
            if (body && body.length > 0) {
                line += " | notes: " + body.substring(0, 100);
            }
            results.push(line);
        }
        results.length > 0 ? results.join("\\n") : "No reminders found";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error listing reminders: \(result.error)", true)
        }
        return (result.output, false)

    case "reminders_search":
        guard let query = args["query"]?.stringValue else {
            return ("Missing required parameter: query", true)
        }
        let limit = args["limit"]?.intValue ?? 25
        let safeQuery = jxaEscape(query)
        let script = """
        var app = Application("Reminders");
        var query = "\(safeQuery)".toLowerCase();
        var limit = \(limit);
        var results = [];
        var lists = app.lists();
        for (var l = 0; l < lists.length && results.length < limit; l++) {
            var reminders = lists[l].reminders();
            for (var i = 0; i < reminders.length && results.length < limit; i++) {
                var r = reminders[i];
                var rName = r.name() || "";
                var rBody = r.body() || "";
                if (rName.toLowerCase().indexOf(query) !== -1 || rBody.toLowerCase().indexOf(query) !== -1) {
                    var line = "[" + lists[l].name() + "] " + rName;
                    var due = r.dueDate();
                    if (due) { line += " | due: " + due.toISOString(); }
                    if (r.completed()) { line += " | completed"; }
                    results.push(line);
                }
            }
        }
        results.length > 0 ? results.join("\\n") : "No reminders found matching: " + query;
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error searching reminders: \(result.error)", true)
        }
        return (result.output, false)

    case "reminders_create":
        guard let reminderName = args["name"]?.stringValue else {
            return ("Missing required parameter: name", true)
        }
        let safeName = jxaEscape(reminderName)
        let listSelector: String
        if let list = args["list"]?.stringValue {
            listSelector = "app.lists.byName(\"\(jxaEscape(list))\")"
        } else {
            listSelector = "app.defaultList()"
        }

        var props = "name: \"\(safeName)\""
        if let notes = args["notes"]?.stringValue {
            props += ", body: \"\(jxaEscape(notes))\""
        }
        if let priority = args["priority"]?.intValue {
            props += ", priority: \(priority)"
        }

        // Due date needs special handling — construct a Date object in JXA
        let dueDateSetup: String
        if let dueDate = args["dueDate"]?.stringValue {
            dueDateSetup = "r.dueDate = new Date(\"\(jxaEscape(dueDate))\");"
        } else {
            dueDateSetup = ""
        }

        let script = """
        var app = Application("Reminders");
        var list = \(listSelector);
        var r = app.Reminder({\(props)});
        list.reminders.push(r);
        \(dueDateSetup)
        var result = "Created reminder: " + r.name();
        var due = r.dueDate();
        if (due) { result += " (due: " + due.toISOString() + ")"; }
        result += " in list: " + list.name();
        result;
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error creating reminder: \(result.error)", true)
        }
        return (result.output, false)

    case "reminders_complete":
        guard let reminderName = args["name"]?.stringValue else {
            return ("Missing required parameter: name", true)
        }
        let completed = args["completed"]?.boolValue ?? true
        let safeName = jxaEscape(reminderName)
        let searchScope: String
        if let list = args["list"]?.stringValue {
            searchScope = "[app.lists.byName(\"\(jxaEscape(list))\")]"
        } else {
            searchScope = "app.lists()"
        }
        let script = """
        var app = Application("Reminders");
        var lists = \(searchScope);
        var found = false;
        for (var l = 0; l < lists.length; l++) {
            var reminders = lists[l].reminders.whose({name: "\(safeName)"})();
            if (reminders.length > 0) {
                reminders[0].completed = \(completed);
                found = true;
                break;
            }
        }
        found ? "Marked \\"\(safeName)\\" as \(completed ? "completed" : "incomplete")" : "Reminder not found: \(safeName)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error completing reminder: \(result.error)", true)
        }
        return (result.output, false)

    case "reminders_delete":
        guard let reminderName = args["name"]?.stringValue else {
            return ("Missing required parameter: name", true)
        }
        let safeName = jxaEscape(reminderName)
        let searchScope: String
        if let list = args["list"]?.stringValue {
            searchScope = "[app.lists.byName(\"\(jxaEscape(list))\")]"
        } else {
            searchScope = "app.lists()"
        }
        let script = """
        var app = Application("Reminders");
        var lists = \(searchScope);
        var found = false;
        for (var l = 0; l < lists.length; l++) {
            var reminders = lists[l].reminders.whose({name: "\(safeName)"})();
            if (reminders.length > 0) {
                app.delete(reminders[0]);
                found = true;
                break;
            }
        }
        found ? "Deleted reminder: \(safeName)" : "Reminder not found: \(safeName)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error deleting reminder: \(result.error)", true)
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
            "name": .string("atelier-reminders"),
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

    FileHandle.standardError.write(Data("reminders: calling \(toolName)\n".utf8))

    let (output, isError) = handleToolCall(name: toolName, args: args)

    FileHandle.standardError.write(Data("reminders: \(toolName) -> \(isError ? "error" : "ok")\n".utf8))

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
