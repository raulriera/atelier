import SwiftUI
import AtelierKit
import AtelierSecurity
import AtelierSandbox

@main
struct AtelierApp: App {
    @State private var fileAccessStore: FileAccessStore = {
        let storeURL = SandboxServiceDelegate.defaultBookmarkStoreURL
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let bookmarkStore = DiskBookmarkStore(fileURL: storeURL)
        let manager = FilePermissionManager(store: bookmarkStore)
        return FileAccessStore(permissionManager: manager, store: bookmarkStore)
    }()

    var body: some Scene {
        WindowGroup {
            ConversationWindow(fileAccessStore: fileAccessStore)
                .task {
                    await fileAccessStore.load()
                }
        }
        .defaultSize(width: 600, height: 700)
    }
}
