import Foundation

/// Shared metadata for displaying MCP capability tools with plain-English names and icons.
enum MCPToolMetadata {

    /// Extracts the bare tool name from an MCP-namespaced tool name.
    /// e.g. "mcp__atelier-finder__finder_trash" → "finder_trash"
    static func bareName(_ name: String) -> String? {
        guard name.hasPrefix("mcp__") else { return nil }
        let parts = name.split(separator: "__")
        guard parts.count >= 3 else { return nil }
        return String(parts.last!)
    }

    /// Returns the short server name from a namespaced tool name.
    /// e.g. "mcp__atelier-finder__finder_trash" → "finder"
    static func serverShortName(_ name: String) -> String? {
        guard name.hasPrefix("mcp__") else { return nil }
        let parts = name.split(separator: "__")
        guard parts.count >= 2 else { return nil }
        let server = String(parts[1])
        if server.hasPrefix("atelier-") {
            return String(server.dropFirst(8))
        }
        return server
    }

    /// Plain-English display name for an MCP tool, or nil if unknown.
    static func displayName(for toolName: String) -> String? {
        guard let bare = bareName(toolName) else { return nil }
        return descriptions[bare]
    }

    /// SF Symbol name for an MCP tool based on its server.
    static func iconName(for toolName: String) -> String? {
        guard let server = serverShortName(toolName) else { return nil }
        return serverIcons[server]
    }

    /// Maps bare MCP tool names to plain-English descriptions.
    private static let descriptions: [String: String] = [
        // Finder
        "finder_list": "List Files",
        "finder_get_info": "Get File Info",
        "finder_open": "Open File",
        "finder_create_folder": "Create Folder",
        "finder_move": "Move",
        "finder_copy": "Copy",
        "finder_rename": "Rename",
        "finder_trash": "Move to Trash",
        "finder_set_tags": "Set Tags",
        // Mail
        "mail_list_mailboxes": "List Mailboxes",
        "mail_search_messages": "Search Email",
        "mail_get_message": "Read Email",
        "mail_move_message": "Move Email",
        "mail_mark_read": "Mark as Read",
        "mail_flag_message": "Flag Email",
        "mail_delete_message": "Delete Email",
        "mail_create_draft": "Create Draft",
        "mail_send_message": "Send Email",
        // Reminders
        "reminders_list_lists": "List Reminder Lists",
        "reminders_list_reminders": "List Reminders",
        "reminders_search": "Search Reminders",
        "reminders_create": "Create Reminder",
        "reminders_complete": "Complete Reminder",
        "reminders_delete": "Delete Reminder",
        // Calendar
        "calendar_list_calendars": "List Calendars",
        "calendar_list_events": "List Events",
        "calendar_search_events": "Search Events",
        "calendar_create_event": "Create Event",
        "calendar_delete_event": "Delete Event",
        // Notes
        "notes_list_folders": "List Note Folders",
        "notes_list_notes": "List Notes",
        "notes_get_note": "Read Note",
        "notes_search": "Search Notes",
        "notes_create": "Create Note",
        "notes_delete": "Delete Note",
        // iWork
        "keynote_create_presentation": "Create Presentation",
        "keynote_add_slide": "Add Slide",
        "keynote_set_slide_content": "Set Slide Content",
        "keynote_set_slide_notes": "Set Slide Notes",
        "keynote_export": "Export Keynote",
        "pages_create_document": "Create Document",
        "pages_insert_text": "Insert Text",
        "pages_export": "Export Pages",
        "numbers_create_spreadsheet": "Create Spreadsheet",
        "numbers_set_cell": "Set Cell",
        "numbers_set_formula": "Set Formula",
        "numbers_export": "Export Numbers",
        // Safari
        "safari_open_url": "Open URL",
        "safari_list_tabs": "List Tabs",
        "safari_get_tab_content": "Read Page",
        "safari_search": "Search the Web",
        "safari_close_tab": "Close Tab",
        "safari_execute_javascript": "Run JavaScript",
        // Preview / PDF
        "pdf_info": "PDF Info",
        "pdf_extract_text": "Extract PDF Text",
        "pdf_merge": "Merge PDFs",
        "pdf_split": "Split PDF",
    ]

    /// SF Symbol name per MCP server.
    private static let serverIcons: [String: String] = [
        "finder": "finder",
        "mail": "envelope",
        "reminders": "checklist",
        "calendar": "calendar",
        "notes": "note.text",
        "iwork": "richtext",
        "safari": "safari",
        "preview": "doc.text.magnifyingglass",
    ]
}
