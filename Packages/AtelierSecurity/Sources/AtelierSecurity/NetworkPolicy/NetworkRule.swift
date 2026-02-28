/// A rule matching network requests by host pattern and optional port.
public struct NetworkRule: Sendable {
    public let hostPattern: String
    public let port: Int?
    public let action: NetworkRuleAction
    public let reason: String

    public init(
        hostPattern: String,
        port: Int? = nil,
        action: NetworkRuleAction,
        reason: String
    ) {
        self.hostPattern = hostPattern
        self.port = port
        self.action = action
        self.reason = reason
    }

    /// Checks if the given host matches this rule's pattern.
    ///
    /// Supports wildcard prefix matching (e.g. `*.anthropic.com` matches `api.anthropic.com`).
    public func matches(host: String, port requestPort: Int?) -> Bool {
        let hostMatches: Bool
        if hostPattern.hasPrefix("*.") {
            let suffix = String(hostPattern.dropFirst(1))
            hostMatches = host.hasSuffix(suffix) || host == String(hostPattern.dropFirst(2))
        } else if hostPattern == "*" {
            hostMatches = true
        } else {
            hostMatches = host == hostPattern
        }

        guard hostMatches else { return false }

        if let rulePort = port {
            return requestPort == rulePort
        }
        return true
    }
}
