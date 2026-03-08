import Foundation
import os

/// Scans a project directory and generates a human-readable context file
/// describing its contents. Works for code projects, document folders,
/// data collections, and everything in between.
///
/// The scan is designed to be fast: it uses `git ls-files` when available
/// (respects `.gitignore`, avoids build artifacts) and falls back to a
/// shallow directory walk otherwise.
///
/// When the Claude CLI is available, sends the file tree to Haiku for a
/// natural-language summary. Falls back to a heuristic render if the CLI
/// is unavailable or the call fails.
public enum ProjectFingerprinter {

    private static let logger = Logger(subsystem: "com.atelier.kit", category: "ProjectFingerprinter")

    /// Result of scanning a project directory.
    public struct Fingerprint: Sendable {
        /// Detected project kind.
        public let kind: ProjectKind
        /// Human-readable category counts (e.g. "Spreadsheets": 47).
        public let categories: [(name: String, count: Int)]
        /// Top-level directory names with file counts.
        public let structure: [(name: String, fileCount: Int)]
        /// Notable files found at the project root.
        public let keyFiles: [String]
        /// Total number of files scanned.
        public let totalFiles: Int
        /// The raw file list (relative paths).
        public let files: [String]
    }

    // MARK: - Public API

    /// Scans the project at `root` and returns a fingerprint.
    ///
    /// Uses `git ls-files` when a `.git` directory exists, otherwise
    /// walks the directory tree (skipping common noise directories).
    public static func scan(at root: URL) -> Fingerprint {
        let files: [String]
        if FileManager.default.fileExists(atPath: root.appendingPathComponent(".git").path) {
            files = gitFiles(at: root)
        } else {
            files = walkFiles(at: root)
        }

        let kind = ProjectDetector.detect(at: root)
        let categories = categorize(files)
        let structure = buildStructure(files)
        let keyFiles = findKeyFiles(files)

        return Fingerprint(
            kind: kind,
            categories: categories,
            structure: structure,
            keyFiles: keyFiles,
            totalFiles: files.count,
            files: files
        )
    }

    /// Produces a natural-language summary of the project by sending the file
    /// tree to Haiku. Falls back to a heuristic render if the CLI is unavailable
    /// or the call fails.
    public static func summarize(
        _ fingerprint: Fingerprint,
        runner: CLIRunner,
        workingDirectory: URL
    ) async -> String {
        let prompt = buildPrompt(fingerprint)

        do {
            let raw = try await runner.run(
                arguments: [
                    "-p",
                    "--output-format", "text",
                    "--model", "haiku",
                    "--max-turns", "1",
                    "--no-session-persistence",
                    "--", prompt,
                ],
                workingDirectory: workingDirectory
            )

            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // Ensure the output starts with the expected heading.
                let content = trimmed.hasPrefix("# ") ? trimmed : "# Project Context\n\n\(trimmed)"
                logger.debug("Haiku fingerprint produced \(content.count) characters")
                return content
            }
        } catch {
            logger.warning("Haiku fingerprint failed, falling back to heuristic: \(error.localizedDescription, privacy: .public)")
        }

        return render(fingerprint)
    }

    /// Renders a fingerprint as markdown using local heuristics only.
    /// Used as a fallback when the CLI is unavailable.
    public static func render(_ fingerprint: Fingerprint) -> String {
        var lines: [String] = []
        lines.append("# Project Context")
        lines.append("")

        // Summary line
        lines.append(summaryLine(fingerprint))
        lines.append("")

        // Content breakdown
        if !fingerprint.categories.isEmpty {
            lines.append("## Contents")
            lines.append("")
            for category in fingerprint.categories {
                lines.append("- \(category.name): \(category.count)")
            }
            lines.append("")
        }

        // Structure
        if !fingerprint.structure.isEmpty {
            lines.append("## Structure")
            lines.append("")
            lines.append("```")
            for folder in fingerprint.structure {
                lines.append("├── \(folder.name)/  ← \(folder.fileCount) files")
            }
            lines.append("```")
            lines.append("")
        }

        // Key files
        if !fingerprint.keyFiles.isEmpty {
            lines.append("## Key files")
            lines.append("")
            for file in fingerprint.keyFiles {
                lines.append("- \(file)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    /// Scans the project and writes `.atelier/context.md` if it doesn't already exist.
    ///
    /// When a `CLIRunner` is provided, uses Haiku for a natural-language summary.
    /// Otherwise falls back to heuristic rendering.
    ///
    /// Returns `true` if a context file was created.
    @discardableResult
    public static func generateIfMissing(
        at root: URL,
        runner: CLIRunner? = nil
    ) async -> Bool {
        let contextPath = root
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("context.md")

        guard !FileManager.default.fileExists(atPath: contextPath.path) else {
            return false
        }

        let fingerprint = scan(at: root)
        guard fingerprint.totalFiles > 0 else { return false }

        let content: String
        if let runner {
            content = await summarize(fingerprint, runner: runner, workingDirectory: root)
        } else {
            content = render(fingerprint)
        }

        let atelierDir = root.appendingPathComponent(".atelier", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: atelierDir,
                withIntermediateDirectories: true
            )
            try content.write(to: contextPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Prompt

    /// Builds a compact prompt for Haiku describing the project's file tree.
    ///
    /// Sends the folder structure (with file counts) and a sample of filenames
    /// rather than every single file path, keeping the prompt small.
    static func buildPrompt(_ fingerprint: Fingerprint) -> String {
        // Build a compact tree: top-level folders with representative files
        var treeLines: [String] = []
        for folder in fingerprint.structure {
            let folderFiles = fingerprint.files
                .filter { $0.hasPrefix(folder.name + "/") }
                .prefix(8)
                .map { "  " + $0 }
            treeLines.append("\(folder.name)/ (\(folder.fileCount) files)")
            treeLines.append(contentsOf: folderFiles)
            if folder.fileCount > 8 {
                treeLines.append("  ... and \(folder.fileCount - 8) more")
            }
        }

        // Root-level files
        let rootFiles = fingerprint.files.filter { !$0.contains("/") }
        if !rootFiles.isEmpty {
            treeLines.append("")
            treeLines.append("Root files:")
            treeLines.append(contentsOf: rootFiles.map { "  " + $0 })
        }

        let tree = treeLines.joined(separator: "\n")

        return """
        <file_tree>
        \(tree)
        </file_tree>

        <stats>
        Total files: \(fingerprint.totalFiles)
        Categories: \(fingerprint.categories.map { "\($0.name) (\($0.count))" }.joined(separator: ", "))
        </stats>

        You are a project analyst. The tags above describe the contents of a folder. \
        Write a brief, human-readable context file that helps an AI assistant understand \
        what this project or folder contains and how it's organized.

        Rules:
        - Start with "# Project Context" heading
        - First paragraph: one or two sentences describing what this is (a payments app, \
        a collection of quarterly reports, a research dataset, etc.)
        - Then a "## Structure" section with a brief description of the main folders and \
        what they contain — use plain language, not file counts
        - If there are notable configuration or key files, mention them briefly
        - Keep the entire output under 20 lines
        - Write for a human, not a developer — no jargon unless the project is clearly \
        a software project
        - Do NOT list file counts or statistics — describe purpose and organization
        - Do NOT wrap output in code fences

        Begin output:
        """
    }

    // MARK: - File collection

    private static func gitFiles(at root: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-files"]
        process.currentDirectoryURL = root

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return walkFiles(at: root)
        }

        // Read pipe data before waitUntilExit to avoid deadlock when
        // output exceeds the pipe buffer size (~64 KB).
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return walkFiles(at: root)
        }

        guard let output = String(data: data, encoding: .utf8) else {
            return walkFiles(at: root)
        }

        return output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .filter { file in
                !skipDirectories.contains(where: { file.hasPrefix($0 + "/") })
            }
    }

    private static func walkFiles(at root: URL) -> [String] {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else { return [] }

        var files: [String] = []
        // Resolve symlinks once for the root (e.g. /var → /private/var on macOS).
        let rootPath = root.resolvingSymlinksInPath().path
        let rootPrefix = rootPath + "/"

        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent

            // Skip noise directories
            if let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               isDir, skipDirectories.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            // Only collect regular files
            guard let isFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                  isFile else { continue }

            // standardizedFileURL normalizes `.` and `..` without a syscall.
            // Fall back to symlink resolution only if the prefix check fails.
            var fullPath = url.standardizedFileURL.path
            if !fullPath.hasPrefix(rootPrefix) {
                fullPath = url.resolvingSymlinksInPath().path
                guard fullPath.hasPrefix(rootPrefix) else { continue }
            }
            files.append(String(fullPath.dropFirst(rootPrefix.count)))
        }

        return files
    }

    // MARK: - Analysis

    private static func categorize(_ files: [String]) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]

        for file in files {
            let ext = (file as NSString).pathExtension.lowercased()
            let category = categoryForExtension(ext)
            counts[category, default: 0] += 1
        }

        return counts
            .sorted { $0.value > $1.value }
            .map { (name: $0.key, count: $0.value) }
    }

    private static func buildStructure(_ files: [String]) -> [(name: String, fileCount: Int)] {
        var folderCounts: [String: Int] = [:]

        for file in files {
            let components = file.components(separatedBy: "/")
            guard components.count > 1 else { continue }
            folderCounts[components[0], default: 0] += 1
        }

        return folderCounts
            .sorted { $0.value > $1.value }
            .prefix(15)
            .map { (name: $0.key, fileCount: $0.value) }
    }

    private static func findKeyFiles(_ files: [String]) -> [String] {
        let rootFiles = files.filter { !$0.contains("/") }
        return rootFiles.filter { file in
            keyFileNames.contains(file) || keyFilePatterns.contains { file.lowercased().hasPrefix($0) }
        }
        .sorted()
    }

    private static func summaryLine(_ fingerprint: Fingerprint) -> String {
        let dominant = fingerprint.categories.first

        switch fingerprint.kind {
        case .code:
            if let main = dominant {
                return "A software project. Mostly \(main.name.lowercased()) (\(main.count) files), \(fingerprint.totalFiles) files total."
            }
            return "A software project with \(fingerprint.totalFiles) files."

        case .writing:
            if let main = dominant {
                return "A collection of \(main.name.lowercased()). \(fingerprint.totalFiles) files total."
            }
            return "A writing project with \(fingerprint.totalFiles) files."

        case .research:
            if let main = dominant {
                return "A data project. Mostly \(main.name.lowercased()) (\(main.count) files), \(fingerprint.totalFiles) files total."
            }
            return "A research project with \(fingerprint.totalFiles) files."

        case .mixed:
            let top = fingerprint.categories.prefix(2)
                .map { "\($0.name.lowercased()) (\($0.count))" }
                .joined(separator: " and ")
            return "A mixed project with \(top). \(fingerprint.totalFiles) files total."

        case .unknown:
            if let main = dominant {
                return "A folder containing \(main.name.lowercased()) (\(main.count) files) and \(fingerprint.totalFiles) files total."
            }
            return "A folder with \(fingerprint.totalFiles) files."
        }
    }

    // MARK: - Categories

    private static func categoryForExtension(_ ext: String) -> String {
        extensionToCategory[ext] ?? "Other"
    }

    /// Single-lookup dictionary mapping file extensions to human-readable categories.
    private static let extensionToCategory: [String: String] = {
        var map: [String: String] = [:]
        let entries: [(String, [String])] = [
            ("Spreadsheets", ["csv", "xlsx", "xls", "tsv", "numbers", "ods"]),
            ("Documents", ["pdf", "doc", "docx", "txt", "rtf", "pages", "odt", "tex", "latex", "org", "epub"]),
            ("Presentations", ["ppt", "pptx", "key", "odp"]),
            ("Images", ["png", "jpg", "jpeg", "gif", "svg", "heic", "heif", "webp", "tiff", "tif", "bmp", "ico", "icns"]),
            ("Data files", ["json", "xml", "yaml", "yml", "toml", "plist", "sqlite", "db", "parquet", "ipynb"]),
            ("Source code", ["swift", "rs", "go", "py", "js", "ts", "jsx", "tsx", "rb", "java", "kt", "kts", "c", "cpp", "cc", "h", "hpp", "m", "mm", "cs", "fs", "ex", "exs", "erl", "hs", "scala", "clj", "cljs", "lua", "r", "jl", "dart", "zig", "nim", "v", "d", "php"]),
            ("Scripts", ["sh", "zsh", "bash", "fish", "bat", "cmd", "ps1", "command"]),
            ("Archives", ["zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg"]),
            ("Configuration", ["ini", "cfg", "conf", "env", "properties"]),
            ("Design files", ["sketch", "fig", "pen", "xd", "ai", "psd"]),
            ("Media", ["mp3", "wav", "aac", "flac", "ogg", "m4a", "mp4", "mov", "avi", "mkv", "webm"]),
            ("Web assets", ["html", "htm", "css", "scss", "sass", "less"]),
        ]
        for (category, extensions) in entries {
            for ext in extensions {
                map[ext] = category
            }
        }
        return map
    }()

    // MARK: - Skip / key file sets

    private static let skipDirectories: Set<String> = [
        ".git", ".atelier", ".claude",
        "node_modules", ".build", "DerivedData",
        "__pycache__", ".venv", "venv", "target",
        ".next", "dist", "build", ".gradle",
        "Pods", ".swiftpm", ".cache", ".turbo",
        "vendor", "coverage", ".pytest_cache",
    ]

    private static let keyFileNames: Set<String> = [
        "Package.swift", "package.json", "Cargo.toml",
        "Makefile", "CMakeLists.txt", "Gemfile",
        "pyproject.toml", "go.mod", "build.gradle",
        "pom.xml", "Podfile", "README.md", "readme.md",
        "LICENSE", "CLAUDE.md", "COWORK.md",
        "docker-compose.yml", "Dockerfile",
        "tsconfig.json", "requirements.txt",
        "Pipfile", "setup.py", "setup.cfg",
    ]

    private static let keyFilePatterns: [String] = [
        "readme", "license", "changelog",
    ]
}
