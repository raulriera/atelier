import Foundation

/// Static registry of all built-in capabilities.
///
/// Each capability maps to an MCP server binary bundled in
/// `Contents/Helpers/` inside the app bundle.
public enum CapabilityRegistry {
    /// All capabilities available in this build.
    public static func allCapabilities() -> [Capability] {
        [
            iWorkCapability(),
            safariCapability(),
            mailCapability(),
            remindersCapability(),
            calendarCapability(),
            notesCapability(),
            finderCapability(),
        ].compactMap { $0 }
    }

    // MARK: - Factory

    private static func capability(
        id: String,
        name: String,
        description: String,
        iconSystemName: String,
        helperName: String,
        toolGroups: [ToolGroup],
        systemPromptHint: String? = nil,
        defaultEnabled: Bool = false
    ) -> Capability? {
        guard let path = CLIEngine.bundledHelperPath(named: helperName) else { return nil }
        return Capability(
            id: id,
            name: name,
            description: description,
            iconSystemName: iconSystemName,
            serverConfig: MCPServerConfig(command: path, serverName: String(helperName.dropLast(4))),
            toolGroups: toolGroups,
            systemPromptHint: systemPromptHint,
            defaultEnabled: defaultEnabled
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
                    description: "Move, flag, and mark messages as read",
                    tools: [
                        "mail_move_message",
                        "mail_mark_read",
                        "mail_flag_message",
                    ]
                ),
                ToolGroup(
                    id: "send",
                    name: "Send",
                    description: "Create email drafts",
                    tools: [
                        "mail_create_draft",
                    ]
                ),
                // mail_send_message is still available but requires user approval
            ]
        )
    }

    // MARK: - Reminders

    static func remindersCapability() -> Capability? {
        capability(
            id: "reminders",
            name: "Reminders",
            description: "Create, complete, and manage reminders and lists.",
            iconSystemName: "checklist",
            helperName: "atelier-reminders-mcp",
            toolGroups: [
                ToolGroup(
                    id: "read",
                    name: "Read",
                    description: "List and search reminders",
                    tools: [
                        "reminders_list_lists",
                        "reminders_list_reminders",
                        "reminders_search",
                    ]
                ),
                ToolGroup(
                    id: "create",
                    name: "Create",
                    description: "Create new reminders with due dates and priorities",
                    tools: [
                        "reminders_create",
                    ]
                ),
                ToolGroup(
                    id: "manage",
                    name: "Manage",
                    description: "Complete reminders",
                    tools: [
                        "reminders_complete",
                    ]
                ),
            ]
        )
    }

    // MARK: - Calendar

    static func calendarCapability() -> Capability? {
        capability(
            id: "calendar",
            name: "Calendar",
            description: "View, create, and manage calendar events.",
            iconSystemName: "calendar",
            helperName: "atelier-calendar-mcp",
            toolGroups: [
                ToolGroup(
                    id: "read",
                    name: "Read",
                    description: "List calendars and view events",
                    tools: [
                        "calendar_list_calendars",
                        "calendar_list_events",
                        "calendar_search_events",
                    ]
                ),
                ToolGroup(
                    id: "create",
                    name: "Create",
                    description: "Create new calendar events",
                    tools: [
                        "calendar_create_event",
                    ]
                ),
                // calendar_delete_event is still available but requires user approval
            ]
        )
    }

    // MARK: - Notes

    static func notesCapability() -> Capability? {
        capability(
            id: "notes",
            name: "Notes",
            description: "Read, create, and manage notes in Apple Notes.",
            iconSystemName: "note.text",
            helperName: "atelier-notes-mcp",
            toolGroups: [
                ToolGroup(
                    id: "read",
                    name: "Read",
                    description: "List folders, browse notes, and search content",
                    tools: [
                        "notes_list_folders",
                        "notes_list_notes",
                        "notes_get_note",
                        "notes_search",
                    ]
                ),
                ToolGroup(
                    id: "create",
                    name: "Create",
                    description: "Create new notes",
                    tools: [
                        "notes_create",
                    ]
                ),
                // notes_delete is still available but requires user approval
            ]
        )
    }

    // MARK: - Finder

    static func finderCapability() -> Capability? {
        capability(
            id: "finder",
            name: "Finder",
            description: "Browse, organize, move, copy, and tag files and folders.",
            iconSystemName: "folder",
            helperName: "atelier-finder-mcp",
            toolGroups: [
                ToolGroup(
                    id: "browse",
                    name: "Browse",
                    description: "List files, get info, and open items",
                    tools: [
                        "finder_list",
                        "finder_get_info",
                        "finder_open",
                    ]
                ),
                ToolGroup(
                    id: "organize",
                    name: "Organize",
                    description: "Create folders, move, copy, rename, and tag files",
                    tools: [
                        "finder_create_folder",
                        "finder_move",
                        "finder_copy",
                        "finder_rename",
                        "finder_set_tags",
                    ]
                ),
            ],
            systemPromptHint: "IMPORTANT: When deleting files, ALWAYS use finder_trash instead of the rm command. finder_trash moves files to the Trash (recoverable), while rm permanently deletes them. Never use Bash rm, rmdir, or unlink for file deletion when Finder is enabled.",
            defaultEnabled: true
        )
    }
}
