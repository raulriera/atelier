import Foundation

/// Stateless scanner that determines the kind of project at a given URL.
public enum ProjectDetector {

    /// Scans the directory at `url` and returns the detected project kind.
    public static func detect(at url: URL) -> ProjectKind {
        let manager = FileManager.default

        guard let contents = try? manager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            // Also check for .git which is hidden
            let hasGit = manager.fileExists(atPath: url.appendingPathComponent(".git").path)
            return hasGit ? .code : .unknown
        }

        let hasGit = manager.fileExists(atPath: url.appendingPathComponent(".git").path)

        var hasCode = hasGit
        var hasWriting = false
        var hasResearch = false

        for item in contents {
            let name = item.lastPathComponent
            let ext = item.pathExtension.lowercased()

            // Code markers
            if codeFilenames.contains(name) || codeExtensions.contains(ext) {
                hasCode = true
            }

            // Writing markers
            if writingExtensions.contains(ext) {
                hasWriting = true
            }

            // Research markers
            if researchExtensions.contains(ext) {
                hasResearch = true
            }

            // Directory-based code markers
            if let isDir = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               isDir, codeDirectoryExtensions.contains(ext) {
                hasCode = true
            }
        }

        let kinds = [hasCode, hasWriting, hasResearch].filter { $0 }.count

        if kinds > 1 { return .mixed }
        if hasCode { return .code }
        if hasWriting { return .writing }
        if hasResearch { return .research }
        return .unknown
    }

    /// Returns `true` if the directory contains a context file (`CLAUDE.md` or `COWORK.md`).
    public static func hasContextFile(at url: URL) -> Bool {
        let manager = FileManager.default
        return contextFilenames.contains(where: {
            manager.fileExists(atPath: url.appendingPathComponent($0).path)
        })
    }

    // MARK: - Marker sets

    private static let codeFilenames: Set<String> = [
        "Package.swift", "package.json", "Cargo.toml", "Makefile",
        "CMakeLists.txt", "Gemfile", "pyproject.toml", "go.mod",
        "build.gradle", "pom.xml", "Podfile",
    ]

    private static let codeExtensions: Set<String> = [
        "swift", "rs", "go", "py", "js", "ts", "rb", "java", "kt", "c", "cpp", "h",
    ]

    private static let codeDirectoryExtensions: Set<String> = [
        "xcodeproj", "xcworkspace",
    ]

    private static let writingExtensions: Set<String> = [
        "md", "markdown", "txt", "docx", "doc", "rtf", "tex", "org",
    ]

    private static let researchExtensions: Set<String> = [
        "csv", "ipynb", "json", "tsv", "parquet", "sqlite", "db",
    ]

    private static let contextFilenames: Set<String> = [
        "CLAUDE.md", "COWORK.md",
    ]
}
