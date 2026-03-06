import Foundation

/// A named subset of tools within a capability that can be independently enabled or disabled.
///
/// For example, a Mail capability might have groups for "Read", "Manage", and "Send",
/// letting users enable reading without granting send access.
public struct ToolGroup: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier within the capability (e.g. "read", "send").
    public let id: String
    /// Human-readable name (e.g. "Read", "Send").
    public let name: String
    /// What this group allows (e.g. "Search and read email messages").
    public let description: String
    /// Bare tool names belonging to this group.
    public let tools: [String]

    public init(id: String, name: String, description: String, tools: [String]) {
        self.id = id
        self.name = name
        self.description = description
        self.tools = tools
    }
}
