//
// atelier-notes-mcp — MCP server that controls Notes.app
// via JXA (JavaScript for Automation) through osascript.
//
// Compiled alongside MCPHelperKit sources via multi-file swiftc.
// All JSON-RPC, JXA, and MCP boilerplate lives in MCPHelperKit.
//

import Foundation

// MARK: - Tool Definitions

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

// MARK: - Entry point

@main enum NotesHelper { static func main() { MCPServer.run(name: "notes", tools: allTools(), handler: handleToolCall) } }
