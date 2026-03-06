import Foundation

/// Tracks tool call success/failure rates per capability and surfaces
/// alerts when a capability becomes unavailable.
///
/// The monitor maps MCP tool names back to capability IDs using
/// ``MCPToolMetadata`` and maintains a sliding window of recent results.
/// When all recent calls to a capability have failed, it generates a
/// one-time alert message for display in the conversation timeline.
@MainActor
@Observable
public final class CapabilityHealthMonitor {

    /// Health state for a capability.
    public enum HealthState: Sendable {
        case healthy
        case degraded
        case unavailable
    }

    /// Current health state per capability ID.
    /// Cached derivation of ``recentResults`` — updated on every record call
    /// to avoid recomputing on observation access.
    public private(set) var health: [String: HealthState] = [:]

    /// Sliding window of recent results per capability ID (true = success).
    private var recentResults: [String: [Bool]] = [:]

    /// Capabilities that have already been alerted as unavailable in this session.
    private var alertedCapabilities: Set<String> = []

    /// Cached capability ID → display name map, built lazily.
    private var nameCache: [String: String] = [:]

    private let windowSize = 5
    private let failureThreshold = 3

    public init() {}

    /// Records a successful tool call for the capability that owns the given tool.
    public func recordSuccess(toolName: String) {
        guard let capID = capabilityID(for: toolName) else { return }
        appendResult(true, for: capID)
    }

    /// Records a failed tool call and returns an alert message if the
    /// capability just became unavailable, or nil otherwise.
    @discardableResult
    public func recordFailure(toolName: String) -> String? {
        guard let capID = capabilityID(for: toolName) else { return nil }
        return appendResult(false, for: capID)
    }

    /// Resets all tracking state. Call when starting a new conversation.
    public func reset() {
        health.removeAll()
        recentResults.removeAll()
        alertedCapabilities.removeAll()
    }

    // MARK: - Private

    /// Returns an alert string if the capability just crossed the unavailable threshold.
    @discardableResult
    private func appendResult(_ success: Bool, for capID: String) -> String? {
        var results = recentResults[capID, default: []]
        results.append(success)
        if results.count > windowSize {
            results.removeFirst(results.count - windowSize)
        }
        recentResults[capID] = results

        let failures = results.filter { !$0 }.count

        if failures >= failureThreshold && !results.suffix(failureThreshold).contains(true) {
            health[capID] = .unavailable
            if !alertedCapabilities.contains(capID) {
                alertedCapabilities.insert(capID)
                return "\(capabilityName(for: capID)) is temporarily unavailable."
            }
        } else if failures > 0 {
            health[capID] = .degraded
        } else {
            health[capID] = .healthy
        }
        return nil
    }

    private func capabilityID(for toolName: String) -> String? {
        MCPToolMetadata.serverShortName(toolName)
    }

    private func capabilityName(for capID: String) -> String {
        if let cached = nameCache[capID] { return cached }
        let name = CapabilityRegistry.allCapabilities()
            .first { $0.id == capID }?.name ?? capID.capitalized
        nameCache[capID] = name
        return name
    }
}
