import Foundation
import Security

/// Real implementation using SecAccessControlCreateWithFlags.
public struct SystemAccessControlProvider: AccessControlProviding {
    public init() {}

    public func create(
        protection: CFTypeRef,
        flags: SecAccessControlCreateFlags
    ) -> SecAccessControl? {
        SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            protection,
            flags,
            nil
        )
    }
}
