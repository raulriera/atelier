import Foundation

/// Static registry of all built-in capabilities.
///
/// Each capability maps to an MCP server binary bundled in
/// `Contents/Helpers/` inside the app bundle.
public enum CapabilityRegistry {
    /// All capabilities available in this build.
    public static func allCapabilities() -> [Capability] {
        [iWorkCapability(), safariCapability(), mailCapability()]
            .compactMap { $0 }
    }

    // MARK: - Factory

    private static func capability(
        id: String,
        name: String,
        description: String,
        iconSystemName: String,
        helperName: String,
        toolGroups: [ToolGroup]
    ) -> Capability? {
        guard let path = CLIEngine.bundledHelperPath(named: helperName) else { return nil }
        return Capability(
            id: id,
            name: name,
            description: description,
            iconSystemName: iconSystemName,
            serverConfig: MCPServerConfig(command: path, serverName: String(helperName.dropLast(4))),
            toolGroups: toolGroups
        )
    }

    // MARK: - iWork

    static func iWorkCapability() -> Capability? {
        capability(
            id: "iwork",
            name: "iWork",
            description: "Create and edit presentations, documents, and spreadsheets in Keynote, Pages, and Numbers.",
            iconSystemName: "doc.richtext",
            helperName: "atelier-iwork-mcp",
            toolGroups: [
                ToolGroup(
                    id: "create",
                    name: "Create",
                    description: "Create and edit documents, presentations, and spreadsheets",
                    tools: [
                        "keynote_create_presentation",
                        "keynote_add_slide",
                        "keynote_set_slide_content",
                        "keynote_set_slide_notes",
                        "pages_create_document",
                        "pages_insert_text",
                        "numbers_create_spreadsheet",
                        "numbers_set_cell",
                        "numbers_set_formula",
                    ]
                ),
                ToolGroup(
                    id: "export",
                    name: "Export",
                    description: "Export documents to PDF, images, and other formats",
                    tools: [
                        "keynote_export",
                        "pages_export",
                        "numbers_export",
                    ]
                ),
            ]
        )
    }

    // MARK: - Safari

    static func safariCapability() -> Capability? {
        capability(
            id: "safari",
            name: "Safari",
            description: "Browse the web, read page content, search, and manage tabs in Safari.",
            iconSystemName: "safari",
            helperName: "atelier-safari-mcp",
            toolGroups: [
                ToolGroup(
                    id: "browse",
                    name: "Browse",
                    description: "Open URLs, list tabs, read page content, and search the web",
                    tools: [
                        "safari_open_url",
                        "safari_list_tabs",
                        "safari_get_tab_content",
                        "safari_search",
                        "safari_close_tab",
                    ]
                ),
                ToolGroup(
                    id: "script",
                    name: "Script",
                    description: "Execute JavaScript in Safari tabs",
                    tools: [
                        "safari_execute_javascript",
                    ]
                ),
            ]
        )
    }

    // MARK: - Mail

    static func mailCapability() -> Capability? {
        capability(
            id: "mail",
            name: "Mail",
            description: "Read, manage, and send email using the Mail app.",
            iconSystemName: "envelope",
            helperName: "atelier-mail-mcp",
            toolGroups: [
                ToolGroup(
                    id: "read",
                    name: "Read",
                    description: "Search and read email messages",
                    tools: [
                        "mail_list_mailboxes",
                        "mail_search_messages",
                        "mail_get_message",
                    ]
                ),
                ToolGroup(
                    id: "manage",
                    name: "Manage",
                    description: "Move, flag, mark as read, and delete messages",
                    tools: [
                        "mail_move_message",
                        "mail_mark_read",
                        "mail_flag_message",
                        "mail_delete_message",
                    ]
                ),
                ToolGroup(
                    id: "send",
                    name: "Send",
                    description: "Create drafts and send email messages",
                    tools: [
                        "mail_create_draft",
                        "mail_send_message",
                    ]
                ),
            ]
        )
    }
}
