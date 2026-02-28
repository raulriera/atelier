import Foundation
import Security

/// Orchestrates credential storage with audit logging.
///
/// Phase 1 scope: API key storage and retrieval via Keychain Services.
public final class CredentialManager: Sendable {
    private let keychainStore: KeychainStoring
    private let auditLogger: AuditLogger

    /// Default service identifier for Atelier API keys.
    public static let defaultService = "com.atelier.credentials"

    public init(
        keychainStore: KeychainStoring = SystemKeychainStore(),
        auditLogger: AuditLogger = NullAuditLogger()
    ) {
        self.keychainStore = keychainStore
        self.auditLogger = auditLogger
    }

    /// Stores an API key in the keychain.
    ///
    /// - Parameters:
    ///   - apiKey: The API key data to store.
    ///   - account: The account identifier for this key.
    ///   - service: The service identifier. Defaults to `defaultService`.
    public func storeAPIKey(
        _ apiKey: Data,
        account: String,
        service: String = CredentialManager.defaultService
    ) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: apiKey,
        ]

        // Try to add; if it already exists, update instead.
        var status = keychainStore.add(query: query)

        if status == errSecDuplicateItem {
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: apiKey,
            ]
            status = keychainStore.update(query: searchQuery, attributes: attributes)
        }

        guard status == errSecSuccess else {
            throw CredentialError.saveFailed(status: status)
        }

        await auditLogger.log(AuditEvent(
            category: .credentialAccess,
            action: "store",
            subject: account,
            detail: "service: \(service)"
        ))
    }

    /// Loads an API key from the keychain.
    ///
    /// - Parameters:
    ///   - account: The account identifier for this key.
    ///   - service: The service identifier. Defaults to `defaultService`.
    /// - Returns: The stored API key data.
    public func loadAPIKey(
        account: String,
        service: String = CredentialManager.defaultService
    ) async throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]

        let (status, result) = keychainStore.copyMatching(query: query)

        guard status != errSecItemNotFound else {
            throw CredentialError.notFound
        }

        guard status == errSecSuccess, let data = result as? Data else {
            throw CredentialError.loadFailed(status: status)
        }

        await auditLogger.log(AuditEvent(
            category: .credentialAccess,
            action: "load",
            subject: account,
            detail: "service: \(service)"
        ))

        return data
    }

    /// Deletes an API key from the keychain.
    ///
    /// - Parameters:
    ///   - account: The account identifier for this key.
    ///   - service: The service identifier. Defaults to `defaultService`.
    public func deleteAPIKey(
        account: String,
        service: String = CredentialManager.defaultService
    ) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = keychainStore.delete(query: query)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialError.deleteFailed(status: status)
        }

        if status == errSecItemNotFound {
            throw CredentialError.notFound
        }

        await auditLogger.log(AuditEvent(
            category: .credentialAccess,
            action: "delete",
            subject: account,
            detail: "service: \(service)"
        ))
    }
}
