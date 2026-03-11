import AppKit
import SwiftUI
import AtelierDesign
import AtelierKit

@main
struct AtelierApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    private let appUpdater = AppUpdater()

    // Each project is its own window — disable macOS tab merging.
    // The SwiftUI `windowTabBehavior` modifier was removed in macOS 26;
    // use the AppKit class property instead.
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

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

    @State private var scheduleStore: ScheduleStore = {
        let url = ScheduleStore.defaultPersistenceURL
        let store = ScheduleStore(persistenceURL: url)
        store.load()
        return store
    }()

    @FocusedValue(\.inspectorVisibility) private var inspectorVisibility
    @FocusedValue(\.newConversation) private var newConversation
    @FocusedValue(\.showAttachmentPicker) private var showAttachmentPicker
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some Scene {
        WindowGroup(for: UUID.self) { $projectID in
            ProjectWindow(
                projectID: projectID,
                projectStore: projectStore,
                scheduleStore: scheduleStore
            )
            .task {
                appDelegate.projectStore = projectStore
                appDelegate.openWindow = openWindow
            }
        } defaultValue: {
            // macOS restores window count and geometry, but SwiftUI may not
            // persist the UUID binding (e.g. after Xcode rebuilds). Fall back
            // to existing projects so restored windows aren't empty.
            (try? projectStore.nextUnclaimedProject())?.id ?? UUID()
        }
        .defaultSize(
            width: Layout.defaultWindowWidth,
            height: Layout.defaultWindowHeight
        )
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appUpdater.updater)
            }

            CommandGroup(after: .toolbar) {
                Button {
                    inspectorVisibility?.wrappedValue.toggle()
                } label: {
                    Text(inspectorVisibility?.wrappedValue == true ? "Hide Inspector" : "Show Inspector")
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(inspectorVisibility == nil)
            }

            CommandMenu("Conversation") {
                Button("New Conversation") {
                    newConversation?()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(newConversation == nil)

                Divider()

                Button("Attach Files...") {
                    showAttachmentPicker?.wrappedValue = true
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(showAttachmentPicker == nil)
            }

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

                let recentProjects = projectStore.allProjects()
                    .filter { $0.rootURL != nil }
                    .prefix(10)

                Menu("Open Recent") {
                    ForEach(Array(recentProjects)) { project in
                        Button(project.displayName) {
                            openWindow(value: project.id)
                        }
                    }
                }
                .disabled(recentProjects.isEmpty)
            }
        }
    }
}
