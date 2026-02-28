import Foundation
import Testing
@testable import AtelierSecurity

@Suite("NetworkPolicyEvaluator")
struct NetworkPolicyEvaluatorTests {

    @Test func allowsAnthropicAPIWithStandardPolicy() {
        let evaluator = NetworkPolicyEvaluator(policy: .standard)

        let request = NetworkRequest(
            host: "api.anthropic.com",
            port: 443,
            method: "POST",
            payloadSize: 1024
        )

        let decision = evaluator.evaluate(request)
        #expect(decision.action == .allow)
        #expect(decision.matchedRule != nil)
        #expect(decision.violations.isEmpty)
    }

    @Test func deniesUnknownHostWithStandardPolicy() {
        let evaluator = NetworkPolicyEvaluator(policy: .standard)

        let request = NetworkRequest(host: "evil.example.com", port: 443)
        let decision = evaluator.evaluate(request)

        #expect(decision.action == .deny)
        #expect(decision.matchedRule == nil)
        #expect(decision.violations.count == 1)
    }

    @Test func deniesOversizedPayload() {
        let policy = NetworkPolicy(
            rules: [
                NetworkRule(hostPattern: "*", action: .allow, reason: "allow all"),
            ],
            payloadPolicy: PayloadPolicy(maxPayloadSize: 100)
        )
        let evaluator = NetworkPolicyEvaluator(policy: policy)

        let request = NetworkRequest(host: "any.com", payloadSize: 200)
        let decision = evaluator.evaluate(request)

        #expect(decision.action == .deny)
        if case .payloadTooLarge(let size, let limit) = decision.violations.first {
            #expect(size == 200)
            #expect(limit == 100)
        } else {
            Issue.record("Expected payloadTooLarge violation")
        }
    }

    @Test func detectsBase64Content() {
        let policy = NetworkPolicy(
            rules: [
                NetworkRule(hostPattern: "*", action: .allow, reason: "allow all"),
            ],
            payloadPolicy: PayloadPolicy(
                blockBase64Content: true,
                base64SampleThreshold: 0.7
            )
        )
        let evaluator = NetworkPolicyEvaluator(policy: policy)

        // A sample that is almost entirely base64-valid characters
        let base64Sample = "SGVsbG8gV29ybGQhIFRoaXMgaXMgYSBiYXNlNjQgc2FtcGxl"
        let request = NetworkRequest(
            host: "any.com",
            payloadSize: 50,
            payloadSample: base64Sample
        )
        let decision = evaluator.evaluate(request)

        #expect(decision.action == .deny)
        let hasBase64Violation = decision.violations.contains {
            if case .suspectedBase64Content = $0 { return true }
            return false
        }
        #expect(hasBase64Violation)
    }

    @Test func firstMatchingRuleWins() {
        let policy = NetworkPolicy(
            rules: [
                NetworkRule(hostPattern: "*.example.com", action: .deny, reason: "block example"),
                NetworkRule(hostPattern: "*", action: .allow, reason: "allow all"),
            ]
        )
        let evaluator = NetworkPolicyEvaluator(policy: policy)

        let request = NetworkRequest(host: "api.example.com")
        let decision = evaluator.evaluate(request)

        #expect(decision.action == .deny)
        #expect(decision.matchedRule?.reason == "block example")
    }

    @Test func defaultActionAppliedWhenNoRuleMatches() {
        let policy = NetworkPolicy(rules: [], defaultAction: .log)
        let evaluator = NetworkPolicyEvaluator(policy: policy)

        let request = NetworkRequest(host: "any.com")
        let decision = evaluator.evaluate(request)

        #expect(decision.action == .log)
    }

    @Test func allowsSentryWithStandardPolicy() {
        let evaluator = NetworkPolicyEvaluator(policy: .standard)

        let request = NetworkRequest(host: "o123.ingest.sentry.io", port: 443)
        let decision = evaluator.evaluate(request)

        #expect(decision.action == .allow)
    }
}
