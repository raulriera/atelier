import AppKit

enum FolderPicker {
    /// Presents an open panel for choosing a single directory.
    @MainActor
    static func chooseFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to grant access"
        panel.prompt = "Grant Access"

        let response = await panel.begin()
        return response == .OK ? panel.url : nil
    }
}
