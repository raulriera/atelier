/// The result of evaluating a network request against a policy.
public struct NetworkPolicyDecision: Sendable {
    public let action: NetworkRuleAction
    public let matchedRule: NetworkRule?
    public let violations: [NetworkPolicyViolation]

    public init(
        action: NetworkRuleAction,
        matchedRule: NetworkRule? = nil,
        violations: [NetworkPolicyViolation] = []
    ) {
        self.action = action
        self.matchedRule = matchedRule
        self.violations = violations
    }
}
