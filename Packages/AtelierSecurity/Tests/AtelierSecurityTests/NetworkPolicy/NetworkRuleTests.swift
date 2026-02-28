import Foundation
import Testing
@testable import AtelierSecurity

@Suite("NetworkRule")
struct NetworkRuleTests {

    @Test func exactHostMatch() {
        let rule = NetworkRule(
            hostPattern: "api.anthropic.com",
            action: .allow,
            reason: "test"
        )

        #expect(rule.matches(host: "api.anthropic.com", port: nil) == true)
        #expect(rule.matches(host: "other.anthropic.com", port: nil) == false)
        #expect(rule.matches(host: "evil.com", port: nil) == false)
    }

    @Test func wildcardSubdomainMatch() {
        let rule = NetworkRule(
            hostPattern: "*.anthropic.com",
            action: .allow,
            reason: "test"
        )

        #expect(rule.matches(host: "api.anthropic.com", port: nil) == true)
        #expect(rule.matches(host: "anthropic.com", port: nil) == true)
        #expect(rule.matches(host: "deep.sub.anthropic.com", port: nil) == true)
        #expect(rule.matches(host: "notanthropic.com", port: nil) == false)
        #expect(rule.matches(host: "evil.com", port: nil) == false)
    }

    @Test func globalWildcardMatchesAll() {
        let rule = NetworkRule(
            hostPattern: "*",
            action: .log,
            reason: "catch-all"
        )

        #expect(rule.matches(host: "anything.example.com", port: nil) == true)
        #expect(rule.matches(host: "localhost", port: nil) == true)
    }

    @Test func portFiltering() {
        let rule = NetworkRule(
            hostPattern: "api.anthropic.com",
            port: 443,
            action: .allow,
            reason: "HTTPS only"
        )

        #expect(rule.matches(host: "api.anthropic.com", port: 443) == true)
        #expect(rule.matches(host: "api.anthropic.com", port: 80) == false)
        #expect(rule.matches(host: "api.anthropic.com", port: nil) == false)
    }

    @Test func noPortRuleMatchesAnyPort() {
        let rule = NetworkRule(
            hostPattern: "api.anthropic.com",
            action: .allow,
            reason: "any port"
        )

        #expect(rule.matches(host: "api.anthropic.com", port: 443) == true)
        #expect(rule.matches(host: "api.anthropic.com", port: 80) == true)
        #expect(rule.matches(host: "api.anthropic.com", port: nil) == true)
    }
}
