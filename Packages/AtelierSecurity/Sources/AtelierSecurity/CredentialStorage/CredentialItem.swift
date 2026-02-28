import Foundation

/// Describes a credential stored in the keychain.
public struct CredentialItem: Sendable {
    /// The service identifier (e.g., "com.atelier.api").
    public let service: String

    /// The account name (e.g., "api-key" or a user identifier).
    public let account: String

    /// When the credential was stored.
    public let createdAt: Date

    public init(
        service: String,
        account: String,
        createdAt: Date = Date()
    ) {
        self.service = service
        self.account = account
        self.createdAt = createdAt
    }
}
