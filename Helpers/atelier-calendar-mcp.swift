#!/usr/bin/env swift
//
// atelier-calendar-mcp — MCP server that controls Calendar.app
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

/// JXA helper that formats a Date as a local ISO 8601 string with timezone
/// offset (e.g. "2026-03-10T20:00:00-04:00") instead of UTC.
/// Injected into every JXA script so Claude sees correct local times.
private let jxaLocalISOHelper = """
function localISO(d) {
    var off = d.getTimezoneOffset();
    var sign = off <= 0 ? "+" : "-";
    off = Math.abs(off);
    var hh = String(Math.floor(off/60)).padStart(2,"0");
    var mm = String(off%60).padStart(2,"0");
    var Y = d.getFullYear();
    var M = String(d.getMonth()+1).padStart(2,"0");
    var D = String(d.getDate()).padStart(2,"0");
    var h = String(d.getHours()).padStart(2,"0");
    var m = String(d.getMinutes()).padStart(2,"0");
    var s = String(d.getSeconds()).padStart(2,"0");
    return Y+"-"+M+"-"+D+"T"+h+":"+m+":"+s+sign+hh+":"+mm;
}
"""

func executeJXA(_ script: String) -> (output: String, error: String, exitCode: Int32) {
    let fullScript = jxaLocalISOHelper + "\n" + script
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-l", "JavaScript", "-e", fullScript]

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

/// Returns a JXA expression that creates a `Date` in **local** time.
///
/// JavaScript's `new Date("2026-03-09")` parses as UTC midnight, which shifts
/// the date by the timezone offset. Appending `T00:00:00` (no trailing `Z`)
/// forces the local-time interpretation. Strings that already contain a `T`
/// (e.g. `"2026-03-09T14:00:00"`) are used as-is.
func jxaLocalDateExpr(_ iso: String) -> String {
    let safe = jxaEscape(iso)
    if safe.contains("T") {
        return "new Date(\"\(safe)\")"
    }
    return "new Date(\"\(safe)T00:00:00\")"
}

/// Returns a JXA expression for the **end** of a date range.
///
/// For date-only strings like `"2026-03-10"`, returns midnight of the
/// **next** day so the range covers the full day. For datetime strings
/// (containing `T`), uses the exact time as-is.
func jxaLocalEndDateExpr(_ iso: String) -> String {
    let safe = jxaEscape(iso)
    if safe.contains("T") {
        return "new Date(\"\(safe)\")"
    }
    // Date-only: end of day = start of next day
    return "(function(){ var d = new Date(\"\(safe)T00:00:00\"); d.setDate(d.getDate()+1); return d; })()"
}

/// Generates a JXA snippet that looks up a calendar by name and throws
/// a descriptive error listing available calendars if it doesn't exist.
///
/// Uses a trimmed comparison so trailing whitespace in calendar names
/// (common with synced calendars) doesn't cause lookup failures.
/// - Parameters:
///   - name: The calendar name to look up (already jxaEscaped).
///   - target: The JXA variable to assign the result to ("cal" or "cals").
///   - asArray: If true, wraps the result in an array: `cals = [found]`.
func calendarLookupScript(name: String, target: String, asArray: Bool) -> String {
    // Search by iterating and trimming, rather than byName() which requires exact match.
    let foundVar = asArray ? target : target
    return """
    (function() {
        var all = app.calendars();
        var needle = "\(name)".trim();
        var found = null;
        for (var i = 0; i < all.length; i++) {
            if (all[i].name().trim() === needle) { found = all[i]; break; }
        }
        if (!found) {
            var names = [];
            for (var i = 0; i < all.length; i++) { names.push(all[i].name()); }
            throw new Error("Calendar \\"" + needle + "\\" not found. Available calendars: " + names.join(", "));
        }
        \(asArray ? "\(foundVar) = [found];" : "\(foundVar) = found;")
    })();
    """
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
            name: "calendar_list_calendars",
            description: "List all calendars in the Calendar app, with their names and colors.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([:])
            ])
        ),
        ToolDefinition(
            name: "calendar_list_events",
            description: "List events in a date range. Defaults to today if no dates are specified.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "startDate": .dict([
                        "type": .string("string"),
                        "description": .string("Start of date range in ISO 8601 format (e.g. \"2026-03-15\"). Defaults to today.")
                    ]),
                    "endDate": .dict([
                        "type": .string("string"),
                        "description": .string("End of date range in ISO 8601 format. Defaults to end of startDate.")
                    ]),
                    "calendar": .dict([
                        "type": .string("string"),
                        "description": .string("Calendar name to filter by. Shows all calendars if omitted.")
                    ]),
                    "limit": .dict([
                        "type": .string("integer"),
                        "description": .string("Maximum number of events to return. Defaults to 50.")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "calendar_search_events",
            description: "Search for events by title across all calendars within an optional date range.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "query": .dict([
                        "type": .string("string"),
                        "description": .string("Search query to match against event titles")
                    ]),
                    "startDate": .dict([
                        "type": .string("string"),
                        "description": .string("Start of search range in ISO 8601 format. Defaults to 30 days ago.")
                    ]),
                    "endDate": .dict([
                        "type": .string("string"),
                        "description": .string("End of search range in ISO 8601 format. Defaults to 30 days from now.")
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
            name: "calendar_create_event",
            description: "Create a new calendar event with a start and end time.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("Event title")
                    ]),
                    "startDate": .dict([
                        "type": .string("string"),
                        "description": .string("Start date/time in ISO 8601 format (e.g. \"2026-03-15T14:00:00\")")
                    ]),
                    "endDate": .dict([
                        "type": .string("string"),
                        "description": .string("End date/time in ISO 8601 format. Defaults to 1 hour after start.")
                    ]),
                    "calendar": .dict([
                        "type": .string("string"),
                        "description": .string("Calendar name to add the event to. Uses the default calendar if omitted.")
                    ]),
                    "location": .dict([
                        "type": .string("string"),
                        "description": .string("Event location")
                    ]),
                    "notes": .dict([
                        "type": .string("string"),
                        "description": .string("Event notes/description")
                    ]),
                    "allDay": .dict([
                        "type": .string("boolean"),
                        "description": .string("Create an all-day event. Defaults to false.")
                    ])
                ]),
                "required": .array([.string("title"), .string("startDate")])
            ])
        ),

        // Manage group
        ToolDefinition(
            name: "calendar_delete_event",
            description: "Delete a calendar event by its title and date. Deletes the first matching event.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "title": .dict([
                        "type": .string("string"),
                        "description": .string("The exact title of the event to delete")
                    ]),
                    "date": .dict([
                        "type": .string("string"),
                        "description": .string("Date of the event in ISO 8601 format (to disambiguate recurring events)")
                    ]),
                    "calendar": .dict([
                        "type": .string("string"),
                        "description": .string("Calendar name to search in. Searches all calendars if omitted.")
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
    case "calendar_list_calendars":
        let script = """
        var app = Application("Calendar");
        var cals = app.calendars();
        var results = [];
        for (var i = 0; i < cals.length; i++) {
            var c = cals[i];
            results.push(c.name().trim() + " (" + c.description() + ")");
        }
        results.length > 0 ? results.join("\\n") : "No calendars found";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error listing calendars: \(result.error)", true)
        }
        return (result.output, false)

    case "calendar_list_events":
        let limit = args["limit"]?.intValue ?? 50
        let startDateExpr: String
        if let startDate = args["startDate"]?.stringValue {
            startDateExpr = jxaLocalDateExpr(startDate)
        } else {
            startDateExpr = "new Date(new Date().setHours(0,0,0,0))"
        }
        let endDateExpr: String
        if let endDate = args["endDate"]?.stringValue {
            endDateExpr = jxaLocalEndDateExpr(endDate)
        } else {
            endDateExpr = "new Date(startDate.getTime() + 24*60*60*1000)"
        }
        let calFilter: String
        if let calendar = args["calendar"]?.stringValue {
            calFilter = calendarLookupScript(name: jxaEscape(calendar), target: "cals", asArray: true)
        } else {
            calFilter = ""
        }
        let script = """
        var app = Application("Calendar");
        var startDate = \(startDateExpr);
        var endDate = \(endDateExpr);
        var cals = app.calendars();
        \(calFilter)
        var limit = \(limit);
        var results = [];
        for (var c = 0; c < cals.length && results.length < limit; c++) {
            var events = cals[c].events.whose({
                _and: [
                    {startDate: {_greaterThanEquals: startDate}},
                    {startDate: {_lessThan: endDate}}
                ]
            })();
            for (var i = 0; i < events.length && results.length < limit; i++) {
                var e = events[i];
                var start = localISO(e.startDate());
                var end = localISO(e.endDate());
                var line = e.summary() + " | " + start + " → " + end;
                if (e.alldayEvent()) { line += " | all-day"; }
                var loc = e.location();
                if (loc && loc.length > 0) { line += " | " + loc; }
                line += " | [" + cals[c].name().trim() + "]";
                results.push(line);
            }
        }
        results.sort();
        results.length > 0 ? results.join("\\n") : "No events found in the specified range";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error listing events: \(result.error)", true)
        }
        return (result.output, false)

    case "calendar_search_events":
        guard let query = args["query"]?.stringValue else {
            return ("Missing required parameter: query", true)
        }
        let limit = args["limit"]?.intValue ?? 25
        let safeQuery = jxaEscape(query)
        let startDateExpr: String
        if let startDate = args["startDate"]?.stringValue {
            startDateExpr = jxaLocalDateExpr(startDate)
        } else {
            startDateExpr = "new Date(Date.now() - 30*24*60*60*1000)"
        }
        let endDateExpr: String
        if let endDate = args["endDate"]?.stringValue {
            endDateExpr = jxaLocalEndDateExpr(endDate)
        } else {
            endDateExpr = "new Date(Date.now() + 30*24*60*60*1000)"
        }
        let script = """
        var app = Application("Calendar");
        var query = "\(safeQuery)".toLowerCase();
        var startDate = \(startDateExpr);
        var endDate = \(endDateExpr);
        var limit = \(limit);
        var results = [];
        var cals = app.calendars();
        for (var c = 0; c < cals.length && results.length < limit; c++) {
            var events = cals[c].events.whose({
                _and: [
                    {startDate: {_greaterThanEquals: startDate}},
                    {startDate: {_lessThan: endDate}}
                ]
            })();
            for (var i = 0; i < events.length && results.length < limit; i++) {
                var e = events[i];
                var title = e.summary() || "";
                if (title.toLowerCase().indexOf(query) !== -1) {
                    var start = localISO(e.startDate());
                    var end = localISO(e.endDate());
                    var line = title + " | " + start + " → " + end;
                    if (e.alldayEvent()) { line += " | all-day"; }
                    line += " | [" + cals[c].name().trim() + "]";
                    results.push(line);
                }
            }
        }
        results.length > 0 ? results.join("\\n") : "No events found matching: " + query;
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error searching events: \(result.error)", true)
        }
        return (result.output, false)

    case "calendar_create_event":
        guard let title = args["title"]?.stringValue,
              let startDate = args["startDate"]?.stringValue else {
            return ("Missing required parameters: title, startDate", true)
        }
        let safeTitle = jxaEscape(title)
        let allDay = args["allDay"]?.boolValue ?? false

        let endDateExpr: String
        if let endDate = args["endDate"]?.stringValue {
            endDateExpr = jxaLocalDateExpr(endDate)
        } else {
            endDateExpr = "new Date(startDate.getTime() + 60*60*1000)"
        }

        let calLookup: String
        if let calendar = args["calendar"]?.stringValue {
            calLookup = calendarLookupScript(name: jxaEscape(calendar), target: "cal", asArray: false)
        } else {
            calLookup = ""
        }

        var extraProps = ""
        if let location = args["location"]?.stringValue {
            extraProps += "\ne.location = \"\(jxaEscape(location))\";"
        }
        if let notes = args["notes"]?.stringValue {
            extraProps += "\ne.description = \"\(jxaEscape(notes))\";"
        }

        let script = """
        var app = Application("Calendar");
        var startDate = \(jxaLocalDateExpr(startDate));
        var endDate = \(endDateExpr);
        var cal = app.calendars[0];
        \(calLookup)
        var e = app.Event({
            summary: "\(safeTitle)",
            startDate: startDate,
            endDate: endDate,
            alldayEvent: \(allDay)
        });
        cal.events.push(e);
        \(extraProps)
        "Created event: " + e.summary() + " on " + localISO(e.startDate()) + " in " + cal.name();
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error creating event: \(result.error)", true)
        }
        return (result.output, false)

    case "calendar_delete_event":
        guard let title = args["title"]?.stringValue else {
            return ("Missing required parameter: title", true)
        }
        let safeTitle = jxaEscape(title)

        let dateFilter: String
        if let date = args["date"]?.stringValue {
            dateFilter = """
            var targetDate = \(jxaLocalDateExpr(date));
            var dayStart = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
            var dayEnd = new Date(dayStart.getTime() + 24*60*60*1000);
            events = events.filter(function(e) {
                var s = e.startDate();
                return s >= dayStart && s < dayEnd;
            });
            """
        } else {
            dateFilter = ""
        }

        let calLookup: String
        if let calendar = args["calendar"]?.stringValue {
            calLookup = calendarLookupScript(name: jxaEscape(calendar), target: "cals", asArray: true)
        } else {
            calLookup = ""
        }

        let script = """
        var app = Application("Calendar");
        var cals = app.calendars();
        \(calLookup)
        var found = false;
        for (var c = 0; c < cals.length; c++) {
            var events = cals[c].events.whose({summary: "\(safeTitle)"})();
            \(dateFilter)
            if (events.length > 0) {
                app.delete(events[0]);
                found = true;
                break;
            }
        }
        found ? "Deleted event: \(safeTitle)" : "Event not found: \(safeTitle)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error deleting event: \(result.error)", true)
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
            "name": .string("atelier-calendar"),
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

    FileHandle.standardError.write(Data("calendar: calling \(toolName) args=\(args)\n".utf8))

    let (output, isError) = handleToolCall(name: toolName, args: args)

    FileHandle.standardError.write(Data("calendar: \(toolName) -> \(isError ? "error" : "ok") output=\(output.prefix(500))\n".utf8))

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
        let wrapped = "<untrusted_document source=\"calendar:\(toolName)\">\n\(output)\n</untrusted_document>"
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
