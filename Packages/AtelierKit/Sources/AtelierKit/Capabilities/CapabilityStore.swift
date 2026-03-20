import Foundation

/// Persists which capabilities and tool groups the user has enabled for a project.
///
/// Follows the same pattern as ``FileAccessStore``: `@Observable`,
/// `@MainActor` mutations, dependency-injected persistence.
@MainActor
@Observable
public final class CapabilityStore {
    public private(set) var capabilities: [Capability] = []
    /// Maps capability ID to the set of enabled group IDs within that capability.
    public private(set) var enabledGroups: [String: Set<String>] = [:]

    /// Convenience: the set of capability IDs that have at least one group enabled.
    public var enabledIDs: Set<String> {
        Set(enabledGroups.filter { !$0.value.isEmpty }.keys)
    }

    private let persistenceURL: URL?

    /// - Parameter persistenceURL: File to persist enabled capability state.
    ///   Pass `nil` for in-memory only (scratchpad / tests).
    public init(persistenceURL: URL? = nil) {
        self.persistenceURL = persistenceURL
    }

    /// Loads the registry and restores persisted enabled state.
    public func load() {
        capabilities = CapabilityRegistry.allCapabilities()

        guard let url = persistenceURL,
              let data = try? Data(contentsOf: url) else {
            // No persisted state — enable default capabilities
            applyDefaults()
            return
        }

        let validIDs = Set(capabilities.map(\.id))

        // Try new format first: [String: [String]]
        if let groupDict = try? JSONDecoder().decode([String: [String]].self, from: data) {
            for (capID, groupIDs) in groupDict where validIDs.contains(capID) {
                enabledGroups[capID] = Set(groupIDs)
            }
        }
        // Fall back to legacy format: Set<String> (enable all groups)
        else if let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            for id in ids.intersection(validIDs) {
                let cap = capabilities.first { $0.id == id }
                let allGroupIDs = Set(cap?.toolGroups.map(\.id) ?? [])
                enabledGroups[id] = allGroupIDs
            }
        }

        // Merge defaults for any new default-on capabilities not yet in the persisted state
        applyDefaults()
    }

    /// Toggles a capability on (all groups) or off entirely and persists the change.
    public func toggle(_ id: String) {
        if let groups = enabledGroups[id], !groups.isEmpty {
            // Store empty set to distinguish "user disabled" from "never seen"
            enabledGroups[id] = []
        } else {
            enableAllGroups(for: id)
        }
        persist()
    }

    /// Toggles a specific tool group within a capability.
    public func toggleGroup(_ groupID: String, for capabilityID: String) {
        var groups = enabledGroups[capabilityID] ?? []
        if groups.contains(groupID) {
            groups.remove(groupID)
        } else {
            groups.insert(groupID)
        }
        enabledGroups[capabilityID] = groups
        persist()
    }

    /// Whether a given capability is currently enabled (has any group enabled).
    public func isEnabled(_ id: String) -> Bool {
        !(enabledGroups[id]?.isEmpty ?? true)
    }

    /// Whether a specific tool group is enabled within a capability.
    public func isGroupEnabled(_ groupID: String, for capabilityID: String) -> Bool {
        enabledGroups[capabilityID]?.contains(groupID) ?? false
    }

    /// Returns enabled capabilities paired with their approved tool names.
    public func enabledCapabilityConfigs() -> [EnabledCapability] {
        capabilities
            .filter { !(enabledGroups[$0.id]?.isEmpty ?? true) }
            .map { cap in
                let groups = enabledGroups[cap.id] ?? []
                let tools = cap.toolGroups
                    .filter { groups.contains($0.id) }
                    .flatMap(\.tools)
                return EnabledCapability(config: cap.serverConfig, approvedTools: tools)
            }
    }

    /// Returns a system prompt fragment describing available capabilities.
    ///
    /// Tells Claude which capabilities are enabled (and what tool groups they provide)
    /// and which are available but disabled (so it can suggest enabling them).
    public func systemPromptFragment() -> String? {
        guard !capabilities.isEmpty else { return nil }

        var enabledLines: [String] = []
        var disabledLines: [String] = []

        for cap in capabilities {
            if let groups = enabledGroups[cap.id], !groups.isEmpty {
                var line = "- \(cap.name): \(cap.description)"
                if !cap.toolGroups.isEmpty {
                    let groupNames = cap.toolGroups
                        .filter { groups.contains($0.id) }
                        .map(\.name)
                    if !groupNames.isEmpty {
                        line += " (enabled: \(groupNames.joined(separator: ", ")))"
                    }
                }
                if let hint = cap.systemPromptHint {
                    line += "\n  " + hint
                }
                enabledLines.append(line)
            } else {
                disabledLines.append("- \(cap.name): \(cap.description)")
            }
        }

        var lines: [String] = []
        if !enabledLines.isEmpty {
            lines.append("# Enabled capabilities")
            lines.append(contentsOf: enabledLines)
        }
        if !disabledLines.isEmpty {
            lines.append("")
            lines.append("# Available capabilities (not yet enabled)")
            lines.append(contentsOf: disabledLines)
            lines.append("")
            lines.append("IMPORTANT: You already have built-in tools (WebSearch, WebFetch, Write, Edit, Bash, Read, Glob, Grep). ALWAYS use these first. Only suggest enabling a capability when it provides something your built-in tools genuinely cannot do (e.g. creating calendar events, managing reminders, controlling Safari tabs). Never refuse a request just because a capability is disabled — use your built-in tools instead.")
            lines.append("When a capability would add clear value beyond built-in tools, mention it by name (e.g. \"I could also help with that if you enable Calendar\"). The app will automatically show an inline Enable button next to your message.")
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// Enables capabilities marked as `defaultEnabled` that aren't already in the persisted state.
    ///
    /// This runs on every load so that newly added default-on capabilities
    /// are enabled even for existing users who already have a persistence file.
    private func applyDefaults() {
        var changed = false
        for cap in capabilities where cap.defaultEnabled && enabledGroups[cap.id] == nil {
            enableAllGroups(for: cap.id)
            changed = true
        }
        if changed {
            persist()
        }
    }

    /// Returns disabled capabilities whose names appear in the given text
    /// as whole words (word-boundary matching to avoid false positives like
    /// "email" matching "Mail" or "footnotes" matching "Notes").
    public func disabledCapabilities(mentionedIn text: String) -> [Capability] {
        return capabilities.filter { cap in
            guard !isEnabled(cap.id) else { return false }
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: cap.name))\\b"
            return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// Enables a capability (all groups) by ID, persisting the change.
    ///
    /// Unlike ``toggle(_:)``, this is idempotent — calling it on an
    /// already-enabled capability is a no-op.
    public func enable(_ id: String) {
        guard !isEnabled(id) else { return }
        enableAllGroups(for: id)
        persist()
    }

    private func enableAllGroups(for id: String) {
        let cap = capabilities.first { $0.id == id }
        enabledGroups[id] = Set(cap?.toolGroups.map(\.id) ?? [])
    }

    /// Sample store populated with preview capabilities (no persistence, no bundle lookup).
    @MainActor
    public static var preview: CapabilityStore {
        let store = CapabilityStore()
        let config = MCPServerConfig(command: "/usr/bin/true", serverName: "preview")
        store.capabilities = [
            Capability(
                id: "mail", name: "Mail", description: "Read, manage, and send email using the Mail app.",
                iconSystemName: "envelope", serverConfig: config,
                toolGroups: [
                    ToolGroup(id: "read", name: "Read", description: "Search and read email messages", tools: ["mail_search"]),
                    ToolGroup(id: "manage", name: "Manage", description: "Move, flag, and mark messages as read", tools: ["mail_move"]),
                    ToolGroup(id: "send", name: "Send", description: "Create drafts and send emails", tools: ["mail_send"]),
                ]
            ),
            Capability(
                id: "reminders", name: "Reminders", description: "Create, complete, and manage reminders and lists.",
                iconSystemName: "checklist", serverConfig: config,
                toolGroups: [
                    ToolGroup(id: "manage", name: "Manage", description: "Create and complete reminders", tools: ["reminders_create"]),
                ]
            ),
            Capability(
                id: "calendar", name: "Calendar", description: "View and create calendar events.",
                iconSystemName: "calendar", serverConfig: config,
                toolGroups: [
                    ToolGroup(id: "read", name: "Read", description: "View upcoming events", tools: ["calendar_list"]),
                    ToolGroup(id: "create", name: "Create", description: "Create new events", tools: ["calendar_create"]),
                ]
            ),
            Capability(
                id: "notes", name: "Notes", description: "Search, read, and create notes.",
                iconSystemName: "note.text", serverConfig: config,
                toolGroups: [
                    ToolGroup(id: "read", name: "Read", description: "Search and read notes", tools: ["notes_search"]),
                    ToolGroup(id: "create", name: "Create", description: "Create new notes", tools: ["notes_create"]),
                ]
            ),
            Capability(
                id: "safari", name: "Safari", description: "Browse the web, read page content, and manage tabs.",
                iconSystemName: "safari", serverConfig: config,
                toolGroups: [
                    ToolGroup(id: "browse", name: "Browse", description: "Open URLs and read page content", tools: ["safari_open"]),
                    ToolGroup(id: "tabs", name: "Tabs", description: "List and manage open tabs", tools: ["safari_tabs"]),
                ]
            ),
        ]
        // Enable a couple for visual variety
        store.enabledGroups = [
            "mail": Set(["read", "send"]),
            "safari": Set(["browse", "tabs"]),
        ]
        return store
    }

    private func persist() {
        guard let url = persistenceURL else { return }
        // Encode as [String: [String]] — group IDs as sorted arrays for stable output
        let encoded = enabledGroups.mapValues { Array($0).sorted() }
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
