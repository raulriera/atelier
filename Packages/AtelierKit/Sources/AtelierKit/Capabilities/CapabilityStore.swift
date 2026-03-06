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
        Set(enabledGroups.keys)
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
            return
        }

        let validIDs = Set(capabilities.map(\.id))

        // Try new format first: [String: [String]]
        if let groupDict = try? JSONDecoder().decode([String: [String]].self, from: data) {
            for (capID, groupIDs) in groupDict where validIDs.contains(capID) {
                enabledGroups[capID] = Set(groupIDs)
            }
            return
        }

        // Fall back to legacy format: Set<String> (enable all groups)
        if let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            for id in ids.intersection(validIDs) {
                let cap = capabilities.first { $0.id == id }
                let allGroupIDs = Set(cap?.toolGroups.map(\.id) ?? [])
                enabledGroups[id] = allGroupIDs
            }
        }
    }

    /// Toggles a capability on (all groups) or off entirely and persists the change.
    public func toggle(_ id: String) {
        if enabledGroups[id] != nil {
            enabledGroups.removeValue(forKey: id)
        } else {
            let cap = capabilities.first { $0.id == id }
            let allGroupIDs = Set(cap?.toolGroups.map(\.id) ?? [])
            enabledGroups[id] = allGroupIDs
        }
        persist()
    }

    /// Toggles a specific tool group within a capability.
    public func toggleGroup(_ groupID: String, for capabilityID: String) {
        var groups = enabledGroups[capabilityID] ?? []
        if groups.contains(groupID) {
            groups.remove(groupID)
            if groups.isEmpty {
                enabledGroups.removeValue(forKey: capabilityID)
            } else {
                enabledGroups[capabilityID] = groups
            }
        } else {
            groups.insert(groupID)
            enabledGroups[capabilityID] = groups
        }
        persist()
    }

    /// Whether a given capability is currently enabled (has any group enabled).
    public func isEnabled(_ id: String) -> Bool {
        enabledGroups[id] != nil
    }

    /// Whether a specific tool group is enabled within a capability.
    public func isGroupEnabled(_ groupID: String, for capabilityID: String) -> Bool {
        enabledGroups[capabilityID]?.contains(groupID) ?? false
    }

    /// Returns enabled capabilities paired with their approved tool names.
    public func enabledCapabilityConfigs() -> [EnabledCapability] {
        capabilities
            .filter { enabledGroups[$0.id] != nil }
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
            if let groups = enabledGroups[cap.id] {
                var line = "- \(cap.name): \(cap.description)"
                if !cap.toolGroups.isEmpty {
                    let groupNames = cap.toolGroups
                        .filter { groups.contains($0.id) }
                        .map(\.name)
                    if !groupNames.isEmpty {
                        line += " (enabled: \(groupNames.joined(separator: ", ")))"
                    }
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
            lines.append("If the user's request would benefit from a disabled capability, let them know it's available and ask them to enable it using the Capabilities button (puzzle piece icon) in the toolbar.")
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func persist() {
        guard let url = persistenceURL else { return }
        // Encode as [String: [String]] — group IDs as sorted arrays for stable output
        let encoded = enabledGroups.mapValues { Array($0).sorted() }
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
