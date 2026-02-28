import Foundation
import Security

/// Abstracts SecAccessControl creation for testability.
public protocol AccessControlProviding: Sendable {
    /// Creates an access control object for keychain items.
    ///
    /// - Parameters:
    ///   - protection: The data protection class (e.g., kSecAttrAccessibleWhenUnlocked).
    ///   - flags: Access control flags (e.g., empty for no biometric requirement).
    /// - Returns: The created access control object, or nil on failure.
    func create(
        protection: CFTypeRef,
        flags: SecAccessControlCreateFlags
    ) -> SecAccessControl?
}
