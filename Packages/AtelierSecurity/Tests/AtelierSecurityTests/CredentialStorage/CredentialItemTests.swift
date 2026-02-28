import Foundation
import Testing
@testable import AtelierSecurity

@Suite("CredentialItem")
struct CredentialItemTests {

    @Test func initializesWithProperties() {
        let date = Date()
        let item = CredentialItem(
            service: "com.atelier.api",
            account: "api-key",
            createdAt: date
        )

        #expect(item.service == "com.atelier.api")
        #expect(item.account == "api-key")
        #expect(item.createdAt == date)
    }

    @Test func defaultsCreatedAtToNow() {
        let before = Date()
        let item = CredentialItem(service: "test", account: "test")
        let after = Date()

        #expect(item.createdAt >= before)
        #expect(item.createdAt <= after)
    }
}
