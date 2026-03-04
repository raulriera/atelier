#!/usr/bin/env swift
//
// atelier-iwork-mcp — MCP server that controls Keynote, Pages, and Numbers
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

/// The project working directory, passed by Atelier via environment.
let workingDirectory = ProcessInfo.processInfo.environment["ATELIER_WORKING_DIRECTORY"]
    ?? FileManager.default.currentDirectoryPath

/// Resolves a user-provided output path. If relative, resolves against the working directory.
func resolveOutputPath(_ path: String) -> String {
    if path.hasPrefix("/") { return path }
    return (workingDirectory as NSString).appendingPathComponent(path)
}

/// Derives a default export path from the frontmost document name of an app.
func defaultExportPath(appName: String, format: String) -> String {
    let script = """
    var app = Application("\(jxaEscape(appName))");
    app.documents[0].name();
    """
    let result = executeJXA(script)
    let docName = result.exitCode == 0 && !result.output.isEmpty
        ? result.output.replacingOccurrences(of: "/", with: "-")
        : "Export"
    let ext: String
    switch format {
    case "pdf": ext = "pdf"
    case "pptx": ext = "pptx"
    case "docx": ext = "docx"
    case "xlsx": ext = "xlsx"
    case "csv": ext = "csv"
    case "images": ext = "png"
    default: ext = format
    }
    return (workingDirectory as NSString).appendingPathComponent("\(docName).\(ext)")
}

// MARK: - Tool Definitions

struct ToolDefinition {
    let name: String
    let description: String
    let inputSchema: AnyCodableValue
}

func allTools() -> [ToolDefinition] {
    [
        // Keynote
        ToolDefinition(
            name: "keynote_create_presentation",
            description: "Create a new Keynote presentation. Returns the document name.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("Title for the presentation (used as document name)")
                    ]),
                    "theme": .dict([
                        "type": .string("string"),
                        "description": .string("Keynote theme name (e.g. 'Basic White', 'Gradient'). Defaults to the standard blank theme if omitted.")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "keynote_add_slide",
            description: "Add a new slide to the frontmost Keynote presentation.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "layout": .dict([
                        "type": .string("string"),
                        "description": .string("Slide layout name (e.g. 'Title & Subtitle', 'Bullet List', 'Blank'). Defaults to 'Blank'.")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "keynote_set_slide_content",
            description: "Set the title and/or body text of a slide in the frontmost Keynote presentation.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "slideIndex": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based index of the slide to modify")
                    ]),
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("Text to set as the slide title")
                    ]),
                    "body": .dict([
                        "type": .string("string"),
                        "description": .string("Text to set as the slide body")
                    ])
                ]),
                "required": .array([.string("slideIndex")])
            ])
        ),
        ToolDefinition(
            name: "keynote_set_slide_notes",
            description: "Set the presenter notes for a slide in the frontmost Keynote presentation.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "slideIndex": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based index of the slide")
                    ]),
                    "notes": .dict([
                        "type": .string("string"),
                        "description": .string("Presenter notes text")
                    ])
                ]),
                "required": .array([.string("slideIndex"), .string("notes")])
            ])
        ),
        ToolDefinition(
            name: "keynote_export",
            description: "Export the frontmost Keynote presentation. Saves to the project directory by default.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "format": .dict([
                        "type": .string("string"),
                        "enum": .array([.string("pdf"), .string("pptx"), .string("images")]),
                        "description": .string("Export format")
                    ]),
                    "outputPath": .dict([
                        "type": .string("string"),
                        "description": .string("Optional file path. Defaults to the project directory with a name derived from the document.")
                    ])
                ]),
                "required": .array([.string("format")])
            ])
        ),
        // Pages
        ToolDefinition(
            name: "pages_create_document",
            description: "Create a new Pages document. Returns the document name.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("Title for the document")
                    ]),
                    "template": .dict([
                        "type": .string("string"),
                        "description": .string("Pages template name (e.g. 'Blank', 'Essay'). Defaults to 'Blank'.")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "pages_insert_text",
            description: "Insert text at the end of the frontmost Pages document.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "text": .dict([
                        "type": .string("string"),
                        "description": .string("Text to insert")
                    ])
                ]),
                "required": .array([.string("text")])
            ])
        ),
        ToolDefinition(
            name: "pages_export",
            description: "Export the frontmost Pages document. Saves to the project directory by default.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "format": .dict([
                        "type": .string("string"),
                        "enum": .array([.string("pdf"), .string("docx")]),
                        "description": .string("Export format")
                    ]),
                    "outputPath": .dict([
                        "type": .string("string"),
                        "description": .string("Optional file path. Defaults to the project directory with a name derived from the document.")
                    ])
                ]),
                "required": .array([.string("format")])
            ])
        ),
        // Numbers
        ToolDefinition(
            name: "numbers_create_spreadsheet",
            description: "Create a new Numbers spreadsheet. Returns the document name.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("Title for the spreadsheet")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "numbers_set_cell",
            description: "Set the value of a cell in the frontmost Numbers spreadsheet.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "sheet": .dict([
                        "type": .string("string"),
                        "description": .string("Sheet name. Defaults to the first sheet.")
                    ]),
                    "row": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based row number")
                    ]),
                    "column": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based column number")
                    ]),
                    "value": .dict([
                        "type": .string("string"),
                        "description": .string("Value to set in the cell")
                    ])
                ]),
                "required": .array([.string("row"), .string("column"), .string("value")])
            ])
        ),
        ToolDefinition(
            name: "numbers_set_formula",
            description: "Set a formula in a cell in the frontmost Numbers spreadsheet.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "sheet": .dict([
                        "type": .string("string"),
                        "description": .string("Sheet name. Defaults to the first sheet.")
                    ]),
                    "row": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based row number")
                    ]),
                    "column": .dict([
                        "type": .string("integer"),
                        "description": .string("1-based column number")
                    ]),
                    "formula": .dict([
                        "type": .string("string"),
                        "description": .string("Formula string (e.g. '=SUM(A1:A10)')")
                    ])
                ]),
                "required": .array([.string("row"), .string("column"), .string("formula")])
            ])
        ),
        ToolDefinition(
            name: "numbers_export",
            description: "Export the frontmost Numbers spreadsheet. Saves to the project directory by default.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "format": .dict([
                        "type": .string("string"),
                        "enum": .array([.string("pdf"), .string("xlsx"), .string("csv")]),
                        "description": .string("Export format")
                    ]),
                    "outputPath": .dict([
                        "type": .string("string"),
                        "description": .string("Optional file path. Defaults to the project directory with a name derived from the document.")
                    ])
                ]),
                "required": .array([.string("format")])
            ])
        ),
    ]
}

// MARK: - Tool Handlers

/// JXA snippet that launches an app and waits until it's ready to receive commands.
func jxaLaunchAndWait(_ appName: String) -> String {
    """
    var app = Application("\(jxaEscape(appName))");
    app.includeStandardAdditions = true;
    app.activate();
    // Wait for the app to be running and responsive
    var tries = 0;
    while (!app.running() && tries < 50) { delay(0.1); tries++; }
    delay(0.3);
    """
}

/// Escapes a Swift string for safe embedding inside a JXA string literal.
func jxaEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
     .replacingOccurrences(of: "\n", with: "\\n")
     .replacingOccurrences(of: "\r", with: "\\r")
     .replacingOccurrences(of: "\t", with: "\\t")
}

func handleToolCall(name: String, args: [String: AnyCodableValue]) -> (String, Bool) {
    switch name {
    // MARK: Keynote
    case "keynote_create_presentation":
        let title = args["title"]?.stringValue ?? "Untitled"
        let theme = args["theme"]?.stringValue
        let safeName = jxaEscape(title)
        var script = jxaLaunchAndWait("Keynote")
        if let theme {
            script += """
            var thm = app.themes.whose({name: "\(jxaEscape(theme))"})[0];
            var doc = app.Document({documentTheme: thm});
            app.documents.push(doc);
            """
        } else {
            script += """
            var doc = app.Document();
            app.documents.push(doc);
            """
        }
        script += """
        doc.name = "\(safeName)";
        "Created presentation: \(safeName)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error creating presentation: \(result.error)", true)
        }
        return ("Created Keynote presentation: \(title)", false)

    case "keynote_add_slide":
        let layout = args["layout"]?.stringValue ?? "Blank"
        let script = """
        var app = Application("Keynote");
        var doc = app.documents[0];
        var layout = doc.slideLayouts.whose({name: "\(jxaEscape(layout))"})[0];
        var slide = app.Slide({baseLayout: layout});
        doc.slides.push(slide);
        "Added slide " + doc.slides.length + " with layout: \(jxaEscape(layout))";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            // Fallback: add without specifying layout
            let fallback = """
            var app = Application("Keynote");
            var doc = app.documents[0];
            var slide = app.Slide();
            doc.slides.push(slide);
            "Added slide " + doc.slides.length;
            """
            let fb = executeJXA(fallback)
            if fb.exitCode != 0 { return ("Error adding slide: \(fb.error)", true) }
            return (fb.output, false)
        }
        return (result.output, false)

    case "keynote_set_slide_content":
        guard let slideIndex = args["slideIndex"]?.intValue else {
            return ("Missing required parameter: slideIndex", true)
        }
        let title = args["title"]?.stringValue
        let body = args["body"]?.stringValue

        var lines = [
            "var app = Application('Keynote');",
            "var doc = app.documents[0];",
            "var slide = doc.slides[\(slideIndex - 1)];",
            "var items = slide.defaultTitleItem ? [slide.defaultTitleItem(), slide.defaultBodyItem()] : [];",
        ]
        if let title {
            lines.append("""
            try { slide.defaultTitleItem().objectText = "\(jxaEscape(title))"; } catch(e) {}
            """)
        }
        if let body {
            lines.append("""
            try { slide.defaultBodyItem().objectText = "\(jxaEscape(body))"; } catch(e) {}
            """)
        }
        lines.append("\"Set content on slide \(slideIndex)\";")
        let script = lines.joined(separator: "\n")
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error setting slide content: \(result.error)", true) }
        return (result.output, false)

    case "keynote_set_slide_notes":
        guard let slideIndex = args["slideIndex"]?.intValue,
              let notes = args["notes"]?.stringValue else {
            return ("Missing required parameters: slideIndex, notes", true)
        }
        let script = """
        var app = Application("Keynote");
        var doc = app.documents[0];
        var slide = doc.slides[\(slideIndex - 1)];
        slide.presenterNotes = "\(jxaEscape(notes))";
        "Set notes on slide \(slideIndex)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error setting notes: \(result.error)", true) }
        return (result.output, false)

    case "keynote_export":
        guard let format = args["format"]?.stringValue else {
            return ("Missing required parameter: format", true)
        }
        let outputPath = args["outputPath"]?.stringValue.map(resolveOutputPath)
            ?? defaultExportPath(appName: "Keynote", format: format)
        let exportFormat: String
        switch format {
        case "pdf": exportFormat = "PDF"
        case "pptx": exportFormat = "Microsoft PowerPoint"
        case "images": exportFormat = "slide images"
        default: return ("Unsupported format: \(format)", true)
        }
        let script = """
        var app = Application("Keynote");
        var doc = app.documents[0];
        app.export(doc, {to: Path("\(jxaEscape(outputPath))"), as: "\(exportFormat)"});
        "Exported to \(jxaEscape(outputPath))";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error exporting: \(result.error)", true) }
        return (result.output, false)

    // MARK: Pages
    case "pages_create_document":
        let title = args["title"]?.stringValue ?? "Untitled"
        let template = args["template"]?.stringValue
        var script: String
        if let template {
            script = jxaLaunchAndWait("Pages") + """
            var tmpl = app.templates.whose({name: "\(jxaEscape(template))"})[0];
            var doc = app.Document({documentTemplate: tmpl});
            app.documents.push(doc);
            doc.name();
            """
        } else {
            script = jxaLaunchAndWait("Pages") + """
            var doc = app.Document();
            app.documents.push(doc);
            doc.name();
            """
        }
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error creating document: \(result.error)", true) }
        return ("Created Pages document: \(title)", false)

    case "pages_insert_text":
        guard let text = args["text"]?.stringValue else {
            return ("Missing required parameter: text", true)
        }
        let script = """
        var app = Application("Pages");
        var doc = app.documents[0];
        var body = doc.bodyText();
        var endOffset = body.length;
        doc.bodyText = body + "\(jxaEscape(text))";
        "Inserted text into Pages document";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error inserting text: \(result.error)", true) }
        return (result.output, false)

    case "pages_export":
        guard let format = args["format"]?.stringValue else {
            return ("Missing required parameter: format", true)
        }
        let outputPath = args["outputPath"]?.stringValue.map(resolveOutputPath)
            ?? defaultExportPath(appName: "Pages", format: format)
        let exportFormat: String
        switch format {
        case "pdf": exportFormat = "PDF"
        case "docx": exportFormat = "Microsoft Word"
        default: return ("Unsupported format: \(format)", true)
        }
        let script = """
        var app = Application("Pages");
        var doc = app.documents[0];
        app.export(doc, {to: Path("\(jxaEscape(outputPath))"), as: "\(exportFormat)"});
        "Exported to \(jxaEscape(outputPath))";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error exporting: \(result.error)", true) }
        return (result.output, false)

    // MARK: Numbers
    case "numbers_create_spreadsheet":
        let title = args["title"]?.stringValue ?? "Untitled"
        let script = jxaLaunchAndWait("Numbers") + """
        var doc = app.Document();
        app.documents.push(doc);
        doc.name();
        """
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error creating spreadsheet: \(result.error)", true) }
        return ("Created Numbers spreadsheet: \(title)", false)

    case "numbers_set_cell":
        guard let row = args["row"]?.intValue,
              let column = args["column"]?.intValue,
              let value = args["value"]?.stringValue else {
            return ("Missing required parameters: row, column, value", true)
        }
        let sheetSelector: String
        if let sheet = args["sheet"]?.stringValue {
            sheetSelector = "doc.sheets.whose({name: \"\(jxaEscape(sheet))\"})[0]"
        } else {
            sheetSelector = "doc.sheets[0]"
        }
        let script = """
        var app = Application("Numbers");
        var doc = app.documents[0];
        var sheet = \(sheetSelector);
        var table = sheet.tables[0];
        var cell = table.cells["\(columnLetter(column))\(row)"];
        cell.value = "\(jxaEscape(value))";
        "Set cell \(columnLetter(column))\(row) to: \(jxaEscape(value))";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error setting cell: \(result.error)", true) }
        return (result.output, false)

    case "numbers_set_formula":
        guard let row = args["row"]?.intValue,
              let column = args["column"]?.intValue,
              let formula = args["formula"]?.stringValue else {
            return ("Missing required parameters: row, column, formula", true)
        }
        let sheetSelector: String
        if let sheet = args["sheet"]?.stringValue {
            sheetSelector = "doc.sheets.whose({name: \"\(jxaEscape(sheet))\"})[0]"
        } else {
            sheetSelector = "doc.sheets[0]"
        }
        let script = """
        var app = Application("Numbers");
        var doc = app.documents[0];
        var sheet = \(sheetSelector);
        var table = sheet.tables[0];
        var cell = table.cells["\(columnLetter(column))\(row)"];
        cell.value = "\(jxaEscape(formula))";
        "Set formula at \(columnLetter(column))\(row)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error setting formula: \(result.error)", true) }
        return (result.output, false)

    case "numbers_export":
        guard let format = args["format"]?.stringValue else {
            return ("Missing required parameter: format", true)
        }
        let outputPath = args["outputPath"]?.stringValue.map(resolveOutputPath)
            ?? defaultExportPath(appName: "Numbers", format: format)
        let exportFormat: String
        switch format {
        case "pdf": exportFormat = "PDF"
        case "xlsx": exportFormat = "Microsoft Excel"
        case "csv": exportFormat = "CSV"
        default: return ("Unsupported format: \(format)", true)
        }
        let script = """
        var app = Application("Numbers");
        var doc = app.documents[0];
        app.export(doc, {to: Path("\(jxaEscape(outputPath))"), as: "\(exportFormat)"});
        "Exported to \(jxaEscape(outputPath))";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 { return ("Error exporting: \(result.error)", true) }
        return (result.output, false)

    default:
        return ("Unknown tool: \(name)", true)
    }
}

/// Converts a 1-based column number to a letter (1=A, 2=B, ..., 26=Z, 27=AA).
func columnLetter(_ column: Int) -> String {
    var result = ""
    var n = column
    while n > 0 {
        n -= 1
        result = String(Character(UnicodeScalar(65 + (n % 26))!)) + result
        n /= 26
    }
    return result
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
            "name": .string("atelier-iwork"),
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

    FileHandle.standardError.write(Data("iwork: calling \(toolName)\n".utf8))

    let (output, isError) = handleToolCall(name: toolName, args: args)

    FileHandle.standardError.write(Data("iwork: \(toolName) -> \(isError ? "error" : "ok")\n".utf8))

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
