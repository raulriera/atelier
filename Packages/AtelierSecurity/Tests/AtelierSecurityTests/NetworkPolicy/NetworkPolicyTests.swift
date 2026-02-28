import Foundation
import Testing
@testable import AtelierSecurity

@Suite("NetworkPolicy")
struct NetworkPolicyTests {

    @Test func standardPolicyHasExpectedDefaults() {
        let policy = NetworkPolicy.standard

        #expect(policy.defaultAction == .deny)
        #expect(policy.rules.count == 2)
        #expect(policy.payloadPolicy.maxPayloadSize == 10_485_760)
        #expect(policy.payloadPolicy.blockBase64Content == true)
    }

    @Test func customPolicyOverridesDefaults() {
        let policy = NetworkPolicy(
            rules: [],
            payloadPolicy: PayloadPolicy(maxPayloadSize: 500),
            defaultAction: .allow
        )

        #expect(policy.defaultAction == .allow)
        #expect(policy.rules.isEmpty)
        #expect(policy.payloadPolicy.maxPayloadSize == 500)
    }

    @Test func payloadPolicyDefaults() {
        let payload = PayloadPolicy()

        #expect(payload.maxPayloadSize == 10_485_760)
        #expect(payload.blockBase64Content == true)
        #expect(payload.base64SampleThreshold == 0.7)
    }
}
