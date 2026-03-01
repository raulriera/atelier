import AppKit

enum FolderPicker {
    /// Presents an open panel for choosing a single directory.
    @MainActor
    static func chooseFolder(
        message: String = "Choose a folder to grant access",
        prompt: String = "Grant Access"
    ) async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = message
        panel.prompt = prompt

        let response = await panel.begin()
        return response == .OK ? panel.url : nil
    }
}
