import Foundation

extension URL {
    /// Returns the path with the home directory prefix replaced by `~`.
    public var abbreviatedPath: String {
        let fullPath = path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if fullPath.hasPrefix(home) {
            return "~" + fullPath.dropFirst(home.count)
        }
        return fullPath
    }
}
