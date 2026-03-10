import SwiftUI
import AtelierKit
import AtelierSecurity

struct ProjectWindow: View {
    let projectStore: ProjectStore
    let scheduleStore: ScheduleStore

    @State private var project: Project?
    @State private var loadError: String?

    init(projectID: UUID, projectStore: ProjectStore, scheduleStore: ScheduleStore) {
        self.projectStore = projectStore
        self.scheduleStore = scheduleStore
        do {
            let loaded = try projectStore.materialize(projectID)
            self._project = State(initialValue: loaded)
        } catch {
            self._loadError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some View {
        Group {
            if let project {
                if project.rootURL != nil {
                    ConversationWindow(
                        projectName: project.displayName,
                        capabilityStore: project.capabilityStore,
                        sessionPersistence: project.sessionPersistence,
                        workingDirectory: project.rootURL,
                        scheduleStore: scheduleStore
                    )
                } else {
                    FolderSelectionView { url in
                        selectFolder(url, for: project)
                    }
                }
            } else if let loadError {
                ContentUnavailableView(
                    "Project Not Found",
                    systemImage: "folder.badge.questionmark",
                    description: Text(loadError)
                )
            }
        }
        .navigationTitle(project?.rootURL != nil ? "" : (project?.displayName ?? ""))
        .task(id: project?.rootURL) {
            guard let project, project.rootURL != nil else { return }
            await project.fileAccessStore.load()
            project.capabilityStore.load()

            if let rootURL = project.rootURL,
               !project.fileAccessStore.entries.contains(where: { $0.url == rootURL }) {
                await project.fileAccessStore.grant(url: rootURL)
            }
        }
    }

    private func selectFolder(_ url: URL, for project: Project) {
        do {
            try projectStore.updateProjectRoot(project.id, rootURL: url)
            project.updateRoot(url: url)
        } catch {
            // Registry write failed — don't update in-memory state.
            // The .task(id:) block won't fire, keeping everything consistent.
        }
        // File access grant happens in .task(id: project?.rootURL) when rootURL changes.
    }
}
