import Foundation
import AtelierSecurity

/// `NSXPCListenerDelegate` for the sandbox XPC service process.
///
/// Configures incoming connections with the `SandboxXPCProtocol` interface
/// and exports a `SandboxServiceHandler` instance.
public final class SandboxServiceDelegate: NSObject, NSXPCListenerDelegate, Sendable {
    private let handler: SandboxServiceHandler

    public init(handler: SandboxServiceHandler = SandboxServiceHandler()) {
        self.handler = handler
    }

    /// Creates a delegate wired for production permission enforcement.
    ///
    /// Uses a `BookmarkBackedPermissionGate` backed by a `DiskBookmarkStore`
    /// at the given URL. The store re-reads from disk on every validation so
    /// grants and revokes from the host app are reflected immediately.
    public static func production(
        bookmarkStoreURL: URL = defaultBookmarkStoreURL,
        auditLogger: AuditLogger = NullAuditLogger()
    ) -> SandboxServiceDelegate {
        try? FileManager.default.createDirectory(
            at: bookmarkStoreURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let store = DiskBookmarkStore(
            fileURL: bookmarkStoreURL,
            reloadBeforeRead: true
        )
        let gate = BookmarkBackedPermissionGate(
            store: store,
            auditLogger: auditLogger
        )
        let handler = SandboxServiceHandler(permissionGate: gate)
        return SandboxServiceDelegate(handler: handler)
    }

    /// Conventional bookmark store location inside Application Support.
    public static var defaultBookmarkStoreURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Atelier", isDirectory: true)
            .appendingPathComponent("bookmarks.json")
    }

    public func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(
            with: SandboxXPCProtocol.self
        )
        newConnection.exportedObject = handler
        newConnection.resume()
        return true
    }
}
