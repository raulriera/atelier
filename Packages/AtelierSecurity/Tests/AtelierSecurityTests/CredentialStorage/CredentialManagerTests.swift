import Foundation
import Testing
@testable import AtelierSecurity

// MARK: - Mocks

private final class MockKeychainStore: KeychainStoring, @unchecked Sendable {
    var storage: [String: Data] = [:]
    var addStatus: OSStatus = errSecSuccess
    var updateStatus: OSStatus = errSecSuccess
    var deleteStatus: OSStatus = errSecSuccess
    var copyStatus: OSStatus = errSecSuccess

    func add(query: [String: Any]) -> OSStatus {
        if addStatus != errSecSuccess { return addStatus }
        let key = makeKey(query)
        if storage[key] != nil { return errSecDuplicateItem }
        storage[key] = query[kSecValueData as String] as? Data
        return errSecSuccess
    }

    func copyMatching(query: [String: Any]) -> (OSStatus, AnyObject?) {
        let key = makeKey(query)
        if let data = storage[key] {
            return (errSecSuccess, data as AnyObject)
        }
        return (errSecItemNotFound, nil)
    }

    func update(query: [String: Any], attributes: [String: Any]) -> OSStatus {
        if updateStatus != errSecSuccess { return updateStatus }
        let key = makeKey(query)
        storage[key] = attributes[kSecValueData as String] as? Data
        return errSecSuccess
    }

    func delete(query: [String: Any]) -> OSStatus {
        if deleteStatus != errSecSuccess { return deleteStatus }
        let key = makeKey(query)
        if storage.removeValue(forKey: key) != nil {
            return errSecSuccess
        }
        return errSecItemNotFound
    }

    private func makeKey(_ query: [String: Any]) -> String {
        let service = query[kSecAttrService as String] as? String ?? ""
        let account = query[kSecAttrAccount as String] as? String ?? ""
        return "\(service):\(account)"
    }
}

@Suite("CredentialManager")
struct CredentialManagerTests {

    @Test func storeAndLoadAPIKey() async throws {
        let keychain = MockKeychainStore()
        let logger = InMemoryAuditLogger()
        let manager = CredentialManager(keychainStore: keychain, auditLogger: logger)

        let apiKey = Data("sk-test-key-12345".utf8)
        try await manager.storeAPIKey(apiKey, account: "claude-api")

        let loaded = try await manager.loadAPIKey(account: "claude-api")
        #expect(loaded == apiKey)

        let events = await logger.events(category: .credentialAccess, since: nil, limit: nil)
        #expect(events.count == 2)
        #expect(events[0].action == "store")
        #expect(events[1].action == "load")
    }

    @Test func storeUpdatesExistingKey() async throws {
        let keychain = MockKeychainStore()
        let manager = CredentialManager(keychainStore: keychain)

        let key1 = Data("key-v1".utf8)
        let key2 = Data("key-v2".utf8)

        try await manager.storeAPIKey(key1, account: "api")
        try await manager.storeAPIKey(key2, account: "api")

        let loaded = try await manager.loadAPIKey(account: "api")
        #expect(loaded == key2)
    }

    @Test func deleteAPIKey() async throws {
        let keychain = MockKeychainStore()
        let logger = InMemoryAuditLogger()
        let manager = CredentialManager(keychainStore: keychain, auditLogger: logger)

        let apiKey = Data("to-delete".utf8)
        try await manager.storeAPIKey(apiKey, account: "temp")
        try await manager.deleteAPIKey(account: "temp")

        do {
            _ = try await manager.loadAPIKey(account: "temp")
            Issue.record("Expected notFound error")
        } catch let error as CredentialError {
            if case .notFound = error {} else {
                Issue.record("Expected notFound, got \(error)")
            }
        }

        let events = await logger.events(category: .credentialAccess, since: nil, limit: nil)
        #expect(events.count == 2) // store + delete
        #expect(events[1].action == "delete")
    }

    @Test func loadNonExistentKeyThrowsNotFound() async {
        let keychain = MockKeychainStore()
        let manager = CredentialManager(keychainStore: keychain)

        do {
            _ = try await manager.loadAPIKey(account: "missing")
            Issue.record("Expected notFound error")
        } catch let error as CredentialError {
            if case .notFound = error {} else {
                Issue.record("Expected notFound, got \(error)")
            }
        } catch {
            Issue.record("Expected CredentialError, got \(error)")
        }
    }

    @Test func deleteNonExistentKeyThrowsNotFound() async {
        let keychain = MockKeychainStore()
        let manager = CredentialManager(keychainStore: keychain)

        do {
            try await manager.deleteAPIKey(account: "missing")
            Issue.record("Expected notFound error")
        } catch let error as CredentialError {
            if case .notFound = error {} else {
                Issue.record("Expected notFound, got \(error)")
            }
        } catch {
            Issue.record("Expected CredentialError, got \(error)")
        }
    }

    @Test func storeFailureThrowsSaveFailed() async {
        let keychain = MockKeychainStore()
        keychain.addStatus = errSecAuthFailed
        let manager = CredentialManager(keychainStore: keychain)

        do {
            try await manager.storeAPIKey(Data("key".utf8), account: "test")
            Issue.record("Expected saveFailed error")
        } catch let error as CredentialError {
            if case .saveFailed = error {} else {
                Issue.record("Expected saveFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected CredentialError, got \(error)")
        }
    }

    @Test func usesCustomService() async throws {
        let keychain = MockKeychainStore()
        let manager = CredentialManager(keychainStore: keychain)

        let key = Data("custom-key".utf8)
        try await manager.storeAPIKey(key, account: "api", service: "com.custom.service")

        let loaded = try await manager.loadAPIKey(account: "api", service: "com.custom.service")
        #expect(loaded == key)

        // Should not find under default service.
        do {
            _ = try await manager.loadAPIKey(account: "api")
            Issue.record("Expected notFound error")
        } catch is CredentialError {
            // Expected
        }
    }
}
