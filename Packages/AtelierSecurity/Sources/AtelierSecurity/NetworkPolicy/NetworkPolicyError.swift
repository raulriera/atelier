/// Errors from network policy evaluation or enforcement.
public enum NetworkPolicyError: Error, Sendable {
    case requestDenied(host: String, reason: String)
    case inspectionFailed(underlying: String)
}
