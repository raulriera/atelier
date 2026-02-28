/// A specific policy violation detected during request evaluation.
public enum NetworkPolicyViolation: Sendable {
    case payloadTooLarge(size: Int, limit: Int)
    case suspectedBase64Content(ratio: Double, threshold: Double)
    case noMatchingRule(host: String)
}
