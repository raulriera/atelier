import Foundation

/// Static registry of all built-in capabilities.
///
/// Each capability maps to an MCP server binary bundled in
/// `Contents/Helpers/` inside the app bundle.
public enum CapabilityRegistry {
    /// All capabilities available in this build.
    public static func allCapabilities() -> [Capability] {
        var capabilities: [Capability] = []
        if let iwork = iWorkCapability() {
            capabilities.append(iwork)
        }
        if let safari = safariCapability() {
            capabilities.append(safari)
        }
        return capabilities
    }

    /// The iWork capability covering Keynote, Pages, and Numbers.
    static func iWorkCapability() -> Capability? {
        guard let helperPath = iWorkHelperPath else { return nil }
        return Capability(
            id: "iwork",
            name: "iWork",
            description: "Create and edit presentations, documents, and spreadsheets in Keynote, Pages, and Numbers.",
            iconSystemName: "doc.richtext",
            serverConfig: MCPServerConfig(
                command: helperPath,
                serverName: "atelier-iwork",
                autoApproveTools: [
                    "keynote_create_presentation",
                    "keynote_add_slide",
                    "keynote_set_slide_content",
                    "keynote_set_slide_notes",
                    "keynote_export",
                    "pages_create_document",
                    "pages_insert_text",
                    "pages_export",
                    "numbers_create_spreadsheet",
                    "numbers_set_cell",
                    "numbers_set_formula",
                    "numbers_export",
                ]
            )
        )
    }

    /// Locates the bundled iWork MCP helper binary.
    static var iWorkHelperPath: String? {
        CLIEngine.bundledHelperPath(named: "atelier-iwork-mcp")
    }

    /// The Safari capability for web browsing and tab management.
    static func safariCapability() -> Capability? {
        guard let helperPath = safariHelperPath else { return nil }
        return Capability(
            id: "safari",
            name: "Safari",
            description: "Browse the web, read page content, search, and manage tabs in Safari.",
            iconSystemName: "safari",
            serverConfig: MCPServerConfig(
                command: helperPath,
                serverName: "atelier-safari",
                autoApproveTools: [
                    "safari_open_url",
                    "safari_list_tabs",
                    "safari_get_tab_content",
                    "safari_execute_javascript",
                    "safari_search",
                    "safari_close_tab",
                ]
            )
        )
    }

    /// Locates the bundled Safari MCP helper binary.
    static var safariHelperPath: String? {
        CLIEngine.bundledHelperPath(named: "atelier-safari-mcp")
    }
}
