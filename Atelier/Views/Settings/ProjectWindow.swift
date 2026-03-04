import SwiftUI
import AtelierKit
import AtelierSecurity

struct ProjectWindow: View {
    let projectStore: ProjectStore

    @State private var project: Project?
    @State private var loadError: String?

    init(projectID: UUID, projectStore: ProjectStore) {
        self.projectStore = projectStore
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
                ConversationWindow(
                    fileAccessStore: project.fileAccessStore,
                    sessionPersistence: project.sessionPersistence,
                    workingDirectory: project.rootURL
                )
            } else if let loadError {
                ContentUnavailableView(
                    "Project Not Found",
                    systemImage: "folder.badge.questionmark",
                    description: Text(loadError)
                )
            }
        }
        .navigationTitle(project?.displayName ?? "")
        .task {
            guard let project else { return }
            await project.fileAccessStore.load()

            if let rootURL = project.rootURL,
               !project.fileAccessStore.entries.contains(where: { $0.url == rootURL }) {
                await project.fileAccessStore.grant(url: rootURL)
            }
        }
    }
}
