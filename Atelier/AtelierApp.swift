import SwiftUI
import AtelierKit

@main
struct AtelierApp: App {
    @State private var projectStore: ProjectStore = {
        let base = ProjectStore.defaultBaseDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let store = ProjectStore(baseDirectory: base)
        try? store.load()

        if ProjectMigration.isMigrationNeeded(baseDirectory: base) {
            _ = try? ProjectMigration.migrateGlobalState(
                baseDirectory: base,
                projectStore: store
            )
        }

        return store
    }()

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some Scene {
        WindowGroup(for: UUID.self) { $projectID in
            ProjectWindow(projectID: projectID, projectStore: projectStore)
        } defaultValue: {
            // macOS restores window count and geometry, but SwiftUI may not
            // persist the UUID binding (e.g. after Xcode rebuilds). Fall back
            // to existing projects so restored windows aren't empty.
            (try? projectStore.nextUnclaimedProject())?.id ?? UUID()
        }
        .defaultSize(width: 600, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    let metadata = try? projectStore.createProject(rootURL: nil)
                    if let id = metadata?.id {
                        openWindow(value: id)
                    }
                }
                .keyboardShortcut("n")

                Button("Open Folder...") {
                    Task { @MainActor in
                        guard let url = await FolderPicker.chooseFolder(
                            message: "Choose a folder to open as a project",
                            prompt: "Open"
                        ) else { return }

                        if let existing = projectStore.findProject(rootURL: url) {
                            try? projectStore.touch(existing.id)
                            dismissWindow(value: existing.id)
                            openWindow(value: existing.id)
                        } else if let metadata = try? projectStore.createProject(rootURL: url) {
                            openWindow(value: metadata.id)
                        }
                    }
                }
                .keyboardShortcut("o")
            }
        }
    }
}
