import SwiftUI
import AtelierKit
import AtelierSecurity
import AtelierSandbox

@main
struct AtelierApp: App {
    @State private var sessionPersistence: DiskSessionPersistence = {
        let directory = DiskSessionPersistence.defaultDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return DiskSessionPersistence(baseDirectory: directory)
    }()

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
            ConversationWindow(fileAccessStore: fileAccessStore, sessionPersistence: sessionPersistence)
                .task {
                    await fileAccessStore.load()
                }
        }
        .defaultSize(width: 600, height: 700)
    }
}
