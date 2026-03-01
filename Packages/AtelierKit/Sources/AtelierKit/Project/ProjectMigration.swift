import Foundation

/// One-time migration from global state to per-project scoped state.
///
/// Checks for legacy global `sessions/` or `bookmarks.json` that predate
/// the per-project directory layout. If found, creates a scratchpad project
/// and moves the files into it.
public enum ProjectMigration {

    /// Returns `true` if the base directory has global state that needs migration.
    public static func isMigrationNeeded(baseDirectory: URL) -> Bool {
        let manager = FileManager.default
        let registryExists = manager.fileExists(
            atPath: baseDirectory.appendingPathComponent("projects.json").path
        )

        // No migration needed if registry already exists
        if registryExists { return false }

        let globalSessions = baseDirectory.appendingPathComponent("sessions", isDirectory: true)
        let globalBookmarks = baseDirectory.appendingPathComponent("bookmarks.json")

        let hasGlobalSessions = manager.fileExists(atPath: globalSessions.path)
        let hasGlobalBookmarks = manager.fileExists(atPath: globalBookmarks.path)

        return hasGlobalSessions || hasGlobalBookmarks
    }

    /// Migrates global sessions and bookmarks into a new scratchpad project.
    ///
    /// - Returns: The migrated project's ID so the app can open that window.
    @MainActor
    public static func migrateGlobalState(
        baseDirectory: URL,
        projectStore: ProjectStore
    ) throws -> UUID {
        let metadata = try projectStore.createProject(rootURL: nil)
        let projectDir = projectStore.projectDirectory(for: metadata.id)

        let manager = FileManager.default
        let globalSessions = baseDirectory.appendingPathComponent("sessions", isDirectory: true)
        let globalBookmarks = baseDirectory.appendingPathComponent("bookmarks.json")
        let targetSessions = projectDir.appendingPathComponent("sessions", isDirectory: true)
        let targetBookmarks = projectDir.appendingPathComponent("bookmarks.json")

        // Move sessions
        if manager.fileExists(atPath: globalSessions.path) {
            let sessionFiles = (try? manager.contentsOfDirectory(
                at: globalSessions,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )) ?? []

            for file in sessionFiles where file.pathExtension == "json" {
                let destination = targetSessions.appendingPathComponent(file.lastPathComponent)
                try? manager.moveItem(at: file, to: destination)
            }

            // Remove the now-empty global sessions directory
            if (try? manager.contentsOfDirectory(atPath: globalSessions.path))?.isEmpty ?? true {
                try? manager.removeItem(at: globalSessions)
            }
        }

        // Move bookmarks
        if manager.fileExists(atPath: globalBookmarks.path) {
            try? manager.moveItem(at: globalBookmarks, to: targetBookmarks)
        }

        return metadata.id
    }
}
