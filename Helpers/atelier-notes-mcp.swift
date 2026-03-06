#!/usr/bin/env swift
//
// atelier-notes-mcp — MCP server that controls Notes.app
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

/// Maximum characters to return from note content reads.
let maxContentLength = 100_000

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
            name: "notes_list_folders",
            description: "List all folders in the Notes app.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([:])
            ])
        ),
        ToolDefinition(
            name: "notes_list_notes",
            description: "List notes in a folder. Shows title, creation date, and modification date. Lists all notes if no folder is specified.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "folder": .dict([
                        "type": .string("string"),
                        "description": .string("Folder name to list notes from. Lists all notes if omitted.")
                    ]),
                    "limit": .dict([
                        "type": .string("integer"),
                        "description": .string("Maximum number of notes to return. Defaults to 50.")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "notes_get_note",
            description: "Read the full content of a note by its exact title. Returns the note's plain text body.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("The exact title of the note to read")
                    ]),
                    "folder": .dict([
                        "type": .string("string"),
                        "description": .string("Folder to search in. Searches all folders if omitted.")
                    ])
                ]),
                "required": .array([.string("title")])
            ])
        ),
        ToolDefinition(
            name: "notes_search",
            description: "Search notes by title or content across all folders.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "query": .dict([
                        "type": .string("string"),
                        "description": .string("Search query to match against note titles and content")
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
            name: "notes_create",
            description: "Create a new note with a title and body text. The body can include HTML formatting.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("Title of the note")
                    ]),
                    "body": .dict([
                        "type": .string("string"),
                        "description": .string("Body text of the note. Can include basic HTML (bold, italic, lists, links).")
                    ]),
                    "folder": .dict([
                        "type": .string("string"),
                        "description": .string("Folder to create the note in. Uses the default folder if omitted.")
                    ])
                ]),
                "required": .array([.string("title"), .string("body")])
            ])
        ),

        // Manage group
        ToolDefinition(
            name: "notes_delete",
            description: "Delete a note by its exact title.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("The exact title of the note to delete")
                    ]),
                    "folder": .dict([
                        "type": .string("string"),
                        "description": .string("Folder to search in. Searches all folders if omitted.")
                    ])
                ]),
                "required": .array([.string("title")])
            ])
        ),
    ]
}

// MARK: - Tool Handlers

func handleToolCall(name: String, args: [String: AnyCodableValue]) -> (String, Bool) {
    switch name {
    case "notes_list_folders":
        let script = """
        var app = Application("Notes");
        var folders = app.folders();
        var results = [];
        for (var i = 0; i < folders.length; i++) {
            var f = folders[i];
            var count = f.notes().length;
            results.push(f.name() + " (" + count + " notes)");
        }
        results.length > 0 ? results.join("\\n") : "No folders found";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error listing folders: \(result.error)", true)
        }
        return (result.output, false)

    case "notes_list_notes":
        let limit = args["limit"]?.intValue ?? 50
        let notesSource: String
        if let folder = args["folder"]?.stringValue {
            notesSource = "app.folders.byName(\"\(jxaEscape(folder))\").notes()"
        } else {
            notesSource = "app.notes()"
        }
        let script = """
        var app = Application("Notes");
        var notes = \(notesSource);
        var limit = \(limit);
        var results = [];
        for (var i = 0; i < Math.min(notes.length, limit); i++) {
            var n = notes[i];
            var title = n.name();
            var created = n.creationDate().toISOString();
            var modified = n.modificationDate().toISOString();
            results.push(title + " | created: " + created + " | modified: " + modified);
        }
        results.length > 0 ? results.join("\\n") : "No notes found";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error listing notes: \(result.error)", true)
        }
        return (result.output, false)

    case "notes_get_note":
        guard let title = args["title"]?.stringValue else {
            return ("Missing required parameter: title", true)
        }
        let safeTitle = jxaEscape(title)
        let searchScope: String
        if let folder = args["folder"]?.stringValue {
            searchScope = "app.folders.byName(\"\(jxaEscape(folder))\").notes"
        } else {
            searchScope = "app.notes"
        }
        let script = """
        var app = Application("Notes");
        var notes = \(searchScope).whose({name: "\(safeTitle)"})();
        if (notes.length === 0) {
            "Note not found: \(safeTitle)";
        } else {
            var n = notes[0];
            var title = n.name();
            var created = n.creationDate().toISOString();
            var modified = n.modificationDate().toISOString();
            var body = n.plaintext() || "(empty)";
            if (body.length > \(maxContentLength)) {
                body = body.substring(0, \(maxContentLength)) + "\\n... (content truncated)";
            }
            "Title: " + title + "\\nCreated: " + created + "\\nModified: " + modified + "\\n\\n" + body;
        }
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error reading note: \(result.error)", true)
        }
        return (result.output, false)

    case "notes_search":
        guard let query = args["query"]?.stringValue else {
            return ("Missing required parameter: query", true)
        }
        let limit = args["limit"]?.intValue ?? 25
        let safeQuery = jxaEscape(query)
        let script = """
        var app = Application("Notes");
        var query = "\(safeQuery)".toLowerCase();
        var limit = \(limit);
        var results = [];
        var notes = app.notes();
        for (var i = 0; i < notes.length && results.length < limit; i++) {
            try {
                var n = notes[i];
                var title = n.name() || "";
                var body = n.plaintext() || "";
                if (title.toLowerCase().indexOf(query) !== -1 || body.toLowerCase().indexOf(query) !== -1) {
                    var modified = n.modificationDate().toISOString();
                    var preview = body.substring(0, 100).replace(/\\n/g, " ");
                    results.push(title + " | modified: " + modified + " | " + preview);
                }
            } catch(e) { continue; }
        }
        results.length > 0 ? results.join("\\n") : "No notes found matching: " + query;
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error searching notes: \(result.error)", true)
        }
        return (result.output, false)

    case "notes_create":
        guard let title = args["title"]?.stringValue,
              let body = args["body"]?.stringValue else {
            return ("Missing required parameters: title, body", true)
        }
        let safeTitle = jxaEscape(title)
        let safeBody = jxaEscape(body)
        let folderSelector: String
        if let folder = args["folder"]?.stringValue {
            folderSelector = "app.folders.byName(\"\(jxaEscape(folder))\")"
        } else {
            folderSelector = "app.defaultAccount().defaultFolder()"
        }
        // Notes.app uses HTML for body content. Wrap plain text in basic HTML.
        let script = """
        var app = Application("Notes");
        var folder = \(folderSelector);
        var htmlBody = "<h1>\(safeTitle)</h1><br>" + "\(safeBody)".split("\\n").join("<br>");
        var n = app.Note({body: htmlBody});
        folder.notes.push(n);
        "Created note: " + n.name() + " in folder: " + folder.name();
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error creating note: \(result.error)", true)
        }
        return (result.output, false)

    case "notes_delete":
        guard let title = args["title"]?.stringValue else {
            return ("Missing required parameter: title", true)
        }
        let safeTitle = jxaEscape(title)
        let searchScope: String
        if let folder = args["folder"]?.stringValue {
            searchScope = "app.folders.byName(\"\(jxaEscape(folder))\").notes"
        } else {
            searchScope = "app.notes"
        }
        let script = """
        var app = Application("Notes");
        var notes = \(searchScope).whose({name: "\(safeTitle)"})();
        if (notes.length === 0) {
            "Note not found: \(safeTitle)";
        } else {
            app.delete(notes[0]);
            "Deleted note: \(safeTitle)";
        }
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error deleting note: \(result.error)", true)
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
            "name": .string("atelier-notes"),
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

    FileHandle.standardError.write(Data("notes: calling \(toolName)\n".utf8))

    let (output, isError) = handleToolCall(name: toolName, args: args)

    FileHandle.standardError.write(Data("notes: \(toolName) -> \(isError ? "error" : "ok")\n".utf8))

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
