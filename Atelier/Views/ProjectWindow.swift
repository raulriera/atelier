import SwiftUI
import AtelierKit
import AtelierSecurity

struct ProjectWindow: View {
    let projectID: UUID
    let projectStore: ProjectStore

    @State private var project: Project?
    @State private var loadError: String?

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
            } else {
                ProgressView()
            }
        }
        .navigationTitle(project?.displayName ?? "Loading")
        .task {
            do {
                let loaded = try projectStore.materialize(projectID)
                await loaded.fileAccessStore.load()

                if let rootURL = loaded.rootURL,
                   !loaded.fileAccessStore.entries.contains(where: { $0.url == rootURL }) {
                    await loaded.fileAccessStore.grant(url: rootURL)
                }

                project = loaded
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}
