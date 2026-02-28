import Foundation

/// Abstracts Keychain Services SecItem operations for testability.
public protocol KeychainStoring: Sendable {
    func add(query: [String: Any]) -> OSStatus
    func copyMatching(query: [String: Any]) -> (OSStatus, AnyObject?)
    func update(query: [String: Any], attributes: [String: Any]) -> OSStatus
    func delete(query: [String: Any]) -> OSStatus
}
