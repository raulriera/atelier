import Foundation

/// Persists which capabilities the user has enabled for a project.
///
/// Follows the same pattern as ``FileAccessStore``: `@Observable`,
/// `@MainActor` mutations, dependency-injected persistence.
@Observable
public final class CapabilityStore {
    public private(set) var capabilities: [Capability] = []
    public private(set) var enabledIDs: Set<String> = []

    private let persistenceURL: URL?

    /// - Parameter persistenceURL: File to persist enabled capability IDs.
    ///   Pass `nil` for in-memory only (scratchpad / tests).
    public init(persistenceURL: URL? = nil) {
        self.persistenceURL = persistenceURL
    }

    /// Loads the registry and restores persisted enabled state.
    @MainActor
    public func load() {
        capabilities = CapabilityRegistry.allCapabilities()

        guard let url = persistenceURL,
              let data = try? Data(contentsOf: url),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return
        }
        // Only keep IDs that still exist in the registry
        enabledIDs = ids.intersection(Set(capabilities.map(\.id)))
    }

    /// Toggles a capability on or off and persists the change.
    @MainActor
    public func toggle(_ id: String) {
        if enabledIDs.contains(id) {
            enabledIDs.remove(id)
        } else {
            enabledIDs.insert(id)
        }
        persist()
    }

    /// Whether a given capability is currently enabled.
    public func isEnabled(_ id: String) -> Bool {
        enabledIDs.contains(id)
    }

    /// Returns MCP server configs for all enabled capabilities.
    public func enabledServerConfigs() -> [MCPServerConfig] {
        capabilities
            .filter { enabledIDs.contains($0.id) }
            .map(\.serverConfig)
    }

    /// Returns a system prompt fragment describing available capabilities.
    ///
    /// Tells Claude which capabilities are enabled (and what tools they provide)
    /// and which are available but disabled (so it can suggest enabling them).
    public func systemPromptFragment() -> String? {
        guard !capabilities.isEmpty else { return nil }

        var enabledLines: [String] = []
        var disabledLines: [String] = []

        for cap in capabilities {
            let line = "- \(cap.name): \(cap.description)"
            if enabledIDs.contains(cap.id) {
                enabledLines.append(line)
            } else {
                disabledLines.append(line)
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
        guard let data = try? JSONEncoder().encode(enabledIDs) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
