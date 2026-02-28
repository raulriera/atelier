import Foundation

/// Evaluates network requests against a policy to produce allow/deny decisions.
public struct NetworkPolicyEvaluator: Sendable {
    private let policy: NetworkPolicy

    public init(policy: NetworkPolicy) {
        self.policy = policy
    }

    /// Evaluates a request against the policy.
    public func evaluate(_ request: NetworkRequest) -> NetworkPolicyDecision {
        var violations: [NetworkPolicyViolation] = []

        // Check payload size
        if request.payloadSize > policy.payloadPolicy.maxPayloadSize {
            violations.append(.payloadTooLarge(
                size: request.payloadSize,
                limit: policy.payloadPolicy.maxPayloadSize
            ))
        }

        // Check for base64 content
        if policy.payloadPolicy.blockBase64Content,
           let sample = request.payloadSample {
            let ratio = base64Ratio(in: sample)
            if ratio >= policy.payloadPolicy.base64SampleThreshold {
                violations.append(.suspectedBase64Content(
                    ratio: ratio,
                    threshold: policy.payloadPolicy.base64SampleThreshold
                ))
            }
        }

        // If payload violations exist, deny immediately
        if !violations.isEmpty {
            return NetworkPolicyDecision(
                action: .deny,
                matchedRule: nil,
                violations: violations
            )
        }

        // Match against rules (first match wins)
        for rule in policy.rules {
            if rule.matches(host: request.host, port: request.port) {
                return NetworkPolicyDecision(
                    action: rule.action,
                    matchedRule: rule,
                    violations: []
                )
            }
        }

        // No rule matched — apply default action
        violations.append(.noMatchingRule(host: request.host))
        return NetworkPolicyDecision(
            action: policy.defaultAction,
            matchedRule: nil,
            violations: violations
        )
    }

    /// Estimates the ratio of base64-like characters in a string sample.
    private func base64Ratio(in sample: String) -> Double {
        guard !sample.isEmpty else { return 0 }
        let base64Chars = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "+/="))
        let matching = sample.unicodeScalars.filter { base64Chars.contains($0) }.count
        return Double(matching) / Double(sample.unicodeScalars.count)
    }
}
