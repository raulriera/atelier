import Foundation

/// A set of rules and payload policies governing network access.
public struct NetworkPolicy: Sendable {
    public let rules: [NetworkRule]
    public let payloadPolicy: PayloadPolicy
    public let defaultAction: NetworkRuleAction

    public init(
        rules: [NetworkRule],
        payloadPolicy: PayloadPolicy = PayloadPolicy(),
        defaultAction: NetworkRuleAction = .deny
    ) {
        self.rules = rules
        self.payloadPolicy = payloadPolicy
        self.defaultAction = defaultAction
    }
}

extension NetworkPolicy {
    /// A standard policy allowing Anthropic API access and denying everything else.
    public static let standard = NetworkPolicy(
        rules: [
            NetworkRule(
                hostPattern: "*.anthropic.com",
                port: 443,
                action: .allow,
                reason: "Anthropic API access"
            ),
            NetworkRule(
                hostPattern: "*.sentry.io",
                port: 443,
                action: .allow,
                reason: "Error reporting"
            ),
        ],
        payloadPolicy: PayloadPolicy(),
        defaultAction: .deny
    )
}
