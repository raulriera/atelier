import Foundation
import AtelierSecurity

/// Observable store that manages folder-level file access grants.
///
/// Wraps ``FilePermissionManager`` and ``BookmarkStore`` to provide a
/// SwiftUI-friendly interface for granting, revoking, and listing
/// security-scoped bookmark entries.
@Observable
public final class FileAccessStore {
    public private(set) var entries: [BookmarkEntry] = []
    public private(set) var error: FileAccessStoreError?

    private let permissionManager: FilePermissionManager
    private let store: BookmarkStore

    public init(permissionManager: FilePermissionManager, store: BookmarkStore) {
        self.permissionManager = permissionManager
        self.store = store
    }

    @MainActor
    public func load() async {
        let all = await store.allEntries()
        entries = all.sorted { $0.url.path < $1.url.path }
    }

    @MainActor
    public func grant(url: URL) async {
        do {
            try await permissionManager.grant(url: url, permission: .readWrite)
            await load()
        } catch {
            self.error = .grantFailed(url: url, underlying: error)
        }
    }

    @MainActor
    public func revoke(url: URL) async {
        await permissionManager.revoke(url: url)
        await load()
    }

    @MainActor
    public func dismissError() {
        error = nil
    }
}
