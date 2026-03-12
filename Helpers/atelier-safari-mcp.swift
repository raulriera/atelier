//
// atelier-safari-mcp — MCP server that controls Safari
// via JXA (JavaScript for Automation) through osascript.
//
// Built on MCPHelperKit for JSON-RPC 2.0, JXA execution, and MCP boilerplate.
// Compiled alongside MCPHelperKit sources via multi-file swiftc.
//

import Foundation

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

// MARK: - Tool Definitions

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

// MARK: - Entry Point

@main enum Safari { static func main() { MCPServer.run(name: "safari", tools: allTools(), handler: handleToolCall) } }
