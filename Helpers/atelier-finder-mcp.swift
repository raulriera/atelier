//
// atelier-finder-mcp — MCP server that controls Finder
// via JXA (JavaScript for Automation) through osascript.
//
// Built on MCPHelperKit for JSON-RPC 2.0, JXA execution, and MCP transport.
// Compiled alongside MCPHelperKit sources via multi-file swiftc.
//
// Operations are scoped to the project's working directory
// (ATELIER_WORKING_DIRECTORY env var) for safety.
//

import Foundation

// MARK: - Finder Utilities

/// The working directory for path resolution and scope safety.
let workingDirectory = ProcessInfo.processInfo.environment["ATELIER_WORKING_DIRECTORY"] ?? NSHomeDirectory()

/// Unicode space characters that macOS uses in filenames (e.g. screenshot names)
/// but LLMs normalize to regular spaces (U+0020).
private let unicodeSpaces: [Character] = [
    "\u{00A0}", // no-break space
    "\u{202F}", // narrow no-break space
    "\u{2007}", // figure space
    "\u{2009}", // thin space
    "\u{200A}", // hair space
]

/// Fixes paths where an LLM normalized Unicode spaces to regular spaces.
/// Uses targeted substitution (trying known Unicode space variants) instead
/// of scanning the entire directory.
func fixUnicodeSpaces(in path: String) -> String {
    let fm = FileManager.default
    if fm.fileExists(atPath: path) { return path }

    // Only fix filenames, not directory components
    let dir = (path as NSString).deletingLastPathComponent
    let name = (path as NSString).lastPathComponent
    guard name.contains(" ") else { return path }

    // Try replacing regular spaces with each Unicode space variant
    for unicodeSpace in unicodeSpaces {
        let candidate = name.replacingOccurrences(of: " ", with: String(unicodeSpace))
        let candidatePath = (dir as NSString).appendingPathComponent(candidate)
        if fm.fileExists(atPath: candidatePath) {
            return candidatePath
        }
    }
    return path
}

/// Resolves a path without scope restriction. Relative paths are resolved
/// from the working directory; absolute paths are accepted as-is.
/// Used for source paths in move/copy where files may come from outside the project.
func resolveAnyPath(_ path: String) -> String {
    let result: String
    if path.hasPrefix("/") { result = (path as NSString).standardizingPath }
    else { result = ((workingDirectory as NSString).appendingPathComponent(path) as NSString).standardizingPath }
    return fixUnicodeSpaces(in: result)
}

/// The working directory with symlinks resolved, for safe prefix matching.
private let resolvedWorkingDirectory = (workingDirectory as NSString).resolvingSymlinksInPath

/// Resolves a user-provided path relative to the working directory.
/// Returns nil if the resolved path escapes the working directory.
/// Uses resolvingSymlinksInPath to prevent symlink-based escapes.
func resolvePath(_ path: String) -> String? {
    let resolved: String
    if path.hasPrefix("/") {
        resolved = path
    } else {
        resolved = (workingDirectory as NSString).appendingPathComponent(path)
    }
    // Resolve symlinks to prevent escapes via symlinks inside the working directory
    let canonical = (resolved as NSString).resolvingSymlinksInPath
    guard canonical.hasPrefix(resolvedWorkingDirectory) || canonical == resolvedWorkingDirectory else {
        return nil
    }
    return fixUnicodeSpaces(in: canonical)
}

// MARK: - Tool Definitions

func allTools() -> [ToolDefinition] {
    [
        // Browse group
        ToolDefinition(
            name: "finder_list",
            description: "List files and folders at a path. Shows name, kind, size, and modification date. Paths are relative to the project directory.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Directory path to list. Defaults to the project root. Relative paths are resolved from the project directory.")
                    ]),
                    "showHidden": .dict([
                        "type": .string("boolean"),
                        "description": .string("Include hidden files (dotfiles). Defaults to false.")
                    ])
                ])
            ])
        ),
        ToolDefinition(
            name: "finder_get_info",
            description: "Get detailed info about a file or folder: size, kind, creation date, modification date, and Finder tags.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the file or folder")
                    ])
                ]),
                "required": .array([.string("path")])
            ])
        ),
        ToolDefinition(
            name: "finder_open",
            description: "Open a file with its default application, or reveal it in Finder.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the file to open")
                    ]),
                    "reveal": .dict([
                        "type": .string("boolean"),
                        "description": .string("If true, reveals the file in Finder instead of opening it. Defaults to false.")
                    ])
                ]),
                "required": .array([.string("path")])
            ])
        ),

        // Organize group
        ToolDefinition(
            name: "finder_create_folder",
            description: "Create a new folder at the specified path.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path for the new folder")
                    ])
                ]),
                "required": .array([.string("path")])
            ])
        ),
        ToolDefinition(
            name: "finder_move",
            description: "Move a file or folder to a new location.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "source": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the file or folder to move")
                    ]),
                    "destination": .dict([
                        "type": .string("string"),
                        "description": .string("Destination directory path")
                    ])
                ]),
                "required": .array([.string("source"), .string("destination")])
            ])
        ),
        ToolDefinition(
            name: "finder_copy",
            description: "Copy a file or folder to a new location.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "source": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the file or folder to copy")
                    ]),
                    "destination": .dict([
                        "type": .string("string"),
                        "description": .string("Destination directory path")
                    ])
                ]),
                "required": .array([.string("source"), .string("destination")])
            ])
        ),
        ToolDefinition(
            name: "finder_rename",
            description: "Rename a file or folder.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the file or folder to rename")
                    ]),
                    "newName": .dict([
                        "type": .string("string"),
                        "description": .string("New name for the file or folder (just the name, not a full path)")
                    ])
                ]),
                "required": .array([.string("path"), .string("newName")])
            ])
        ),
        ToolDefinition(
            name: "finder_trash",
            description: "Move a file or folder to the Trash.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the file or folder to trash")
                    ])
                ]),
                "required": .array([.string("path")])
            ])
        ),
        ToolDefinition(
            name: "finder_set_tags",
            description: "Set Finder tags on a file or folder. Replaces existing tags.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the file or folder")
                    ]),
                    "tags": .dict([
                        "type": .string("array"),
                        "items": .dict(["type": .string("string")]),
                        "description": .string("Array of tag names to set (e.g. [\"Important\", \"Work\"]). Use an empty array to clear tags.")
                    ])
                ]),
                "required": .array([.string("path"), .string("tags")])
            ])
        ),
    ]
}

// MARK: - Tool Handlers

func handleToolCall(name: String, args: [String: AnyCodableValue]) -> (String, Bool) {
    switch name {
    case "finder_list":
        let rawPath = args["path"]?.stringValue ?? "."
        guard let path = resolvePath(rawPath) else {
            return ("Error: path is outside the project directory", true)
        }
        let showHidden = args["showHidden"]?.boolValue ?? false
        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(atPath: path)
            let formatter = ISO8601DateFormatter()
            var lines: [String] = []
            for name in contents.sorted() {
                if !showHidden && name.hasPrefix(".") { continue }
                let fullPath = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)
                let kind = isDir.boolValue ? "Folder" : "File"
                var line = "\(name) | \(kind)"
                if let attrs = try? fm.attributesOfItem(atPath: fullPath) {
                    if let size = attrs[.size] as? Int64, !isDir.boolValue {
                        line += " | \(size) bytes"
                    }
                    if let mod = attrs[.modificationDate] as? Date {
                        line += " | \(formatter.string(from: mod))"
                    }
                }
                lines.append(line)
            }
            return (lines.isEmpty ? "Empty directory" : lines.joined(separator: "\n"), false)
        } catch {
            return ("Error listing directory: \(error.localizedDescription)", true)
        }

    case "finder_get_info":
        guard let rawPath = args["path"]?.stringValue else {
            return ("Missing required parameter: path", true)
        }
        guard let path = resolvePath(rawPath) else {
            return ("Error: path is outside the project directory", true)
        }
        // Use FileManager for reliable file info
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: path) else {
            return ("Error: file not found at \(path)", true)
        }
        let name = (path as NSString).lastPathComponent
        let kind = (attrs[.type] as? FileAttributeType) == .typeDirectory ? "Folder" : "File"
        let size = attrs[.size] as? Int64
        let created = attrs[.creationDate] as? Date
        let modified = attrs[.modificationDate] as? Date
        let formatter = ISO8601DateFormatter()
        var lines = [
            "Name: \(name)",
            "Kind: \(kind)",
            "Size: \(size.map { "\($0) bytes" } ?? "N/A")",
            "Created: \(created.map { formatter.string(from: $0) } ?? "N/A")",
            "Modified: \(modified.map { formatter.string(from: $0) } ?? "N/A")",
        ]
        // Read Finder tags via ObjC bridge
        let safePath = jxaEscape(path)
        let tagScript = """
        ObjC.import("Foundation");
        var url = $.NSURL.fileURLWithPath("\(safePath)");
        var tagRef = Ref();
        url.getResourceValueForKeyError(tagRef, "NSURLTagNamesKey", null);
        var tags = tagRef[0];
        if (tags && tags.count > 0) {
            var arr = [];
            for (var i = 0; i < tags.count; i++) arr.push(tags.objectAtIndex(i).js);
            arr.join(", ");
        } else { ""; }
        """
        let tagResult = executeJXA(tagScript)
        if tagResult.exitCode == 0 && !tagResult.output.isEmpty {
            lines.append("Tags: \(tagResult.output)")
        }
        return (lines.joined(separator: "\n"), false)

    case "finder_open":
        guard let rawPath = args["path"]?.stringValue else {
            return ("Missing required parameter: path", true)
        }
        guard let path = resolvePath(rawPath) else {
            return ("Error: path is outside the project directory", true)
        }
        let reveal = args["reveal"]?.boolValue ?? false
        if reveal {
            // Use NSWorkspace to reveal in Finder
            let safePath = jxaEscape(path)
            let script = """
            ObjC.import("AppKit");
            $.NSWorkspace.sharedWorkspace.selectFileInFileViewerRootedAtPath("\(safePath)", "");
            "Revealed in Finder: \(safePath)";
            """
            let result = executeJXA(script)
            if result.exitCode != 0 {
                return ("Error revealing: \(result.error)", true)
            }
            return (result.output, false)
        } else {
            // Use NSWorkspace to open with default app
            let safePath = jxaEscape(path)
            let script = """
            ObjC.import("AppKit");
            var url = $.NSURL.fileURLWithPath("\(safePath)");
            $.NSWorkspace.sharedWorkspace.openURL(url);
            "Opened: \(safePath)";
            """
            let result = executeJXA(script)
            if result.exitCode != 0 {
                return ("Error opening: \(result.error)", true)
            }
            return (result.output, false)
        }

    case "finder_create_folder":
        guard let rawPath = args["path"]?.stringValue else {
            return ("Missing required parameter: path", true)
        }
        guard let path = resolvePath(rawPath) else {
            return ("Error: path is outside the project directory", true)
        }
        // Use FileManager for reliable folder creation
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            return ("Created folder: \(path)", false)
        } catch {
            return ("Error creating folder: \(error.localizedDescription)", true)
        }

    case "finder_move":
        guard let rawSource = args["source"]?.stringValue,
              let rawDest = args["destination"]?.stringValue else {
            return ("Missing required parameters: source, destination", true)
        }
        // Source can be anywhere (e.g. a screenshot from /var/folders),
        // but destination must be inside the project directory.
        let source = resolveAnyPath(rawSource)
        guard let destination = resolvePath(rawDest) else {
            return ("Error: destination path is outside the project directory", true)
        }
        let sourceName = (source as NSString).lastPathComponent
        let destPath = (destination as NSString).appendingPathComponent(sourceName)
        do {
            // Auto-create destination directory if needed
            try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
            try FileManager.default.moveItem(atPath: source, toPath: destPath)
            return ("Moved \(sourceName) to \(destination)", false)
        } catch {
            return ("Error moving: \(error.localizedDescription)", true)
        }

    case "finder_copy":
        guard let rawSource = args["source"]?.stringValue,
              let rawDest = args["destination"]?.stringValue else {
            return ("Missing required parameters: source, destination", true)
        }
        // Source can be anywhere, destination must be inside the project.
        let source = resolveAnyPath(rawSource)
        guard let destination = resolvePath(rawDest) else {
            return ("Error: destination path is outside the project directory", true)
        }
        let sourceName = (source as NSString).lastPathComponent
        let destPath = (destination as NSString).appendingPathComponent(sourceName)
        do {
            // Auto-create destination directory if needed
            try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
            try FileManager.default.copyItem(atPath: source, toPath: destPath)
            return ("Copied \(sourceName) to \(destination)", false)
        } catch {
            return ("Error copying: \(error.localizedDescription)", true)
        }

    case "finder_rename":
        guard let rawPath = args["path"]?.stringValue,
              let newName = args["newName"]?.stringValue else {
            return ("Missing required parameters: path, newName", true)
        }
        guard let path = resolvePath(rawPath) else {
            return ("Error: path is outside the project directory", true)
        }
        let oldName = (path as NSString).lastPathComponent
        let parent = (path as NSString).deletingLastPathComponent
        let newPath = (parent as NSString).appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(atPath: path, toPath: newPath)
            return ("Renamed \(oldName) to \(newName)", false)
        } catch {
            return ("Error renaming: \(error.localizedDescription)", true)
        }

    case "finder_trash":
        guard let rawPath = args["path"]?.stringValue else {
            return ("Missing required parameter: path", true)
        }
        guard let path = resolvePath(rawPath) else {
            return ("Error: path is outside the project directory", true)
        }
        // Use NSFileManager moveItemToTrash via ObjC bridge — more reliable than Finder scripting
        let safePath = jxaEscape(path)
        let script = """
        ObjC.import("Foundation");
        var fm = $.NSFileManager.defaultManager;
        var url = $.NSURL.fileURLWithPath("\(safePath)");
        var ref = Ref();
        var ok = fm.trashItemAtURLResultingItemURLError(url, ref, null);
        if (!ok) { throw new Error("Failed to move to Trash"); }
        "Moved to Trash: \(safePath)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error trashing: \(result.error)", true)
        }
        return (result.output, false)

    case "finder_set_tags":
        guard let rawPath = args["path"]?.stringValue else {
            return ("Missing required parameter: path", true)
        }
        guard let path = resolvePath(rawPath) else {
            return ("Error: path is outside the project directory", true)
        }
        // Extract tags from the array parameter
        var tagNames: [String] = []
        if case .array(let arr) = args["tags"] {
            tagNames = arr.compactMap(\.stringValue)
        }
        // Use xattr to set Finder tags (com.apple.metadata:_kMDItemUserTags)
        let tagList = tagNames.map { "\"\(jxaEscape($0))\"" }.joined(separator: ", ")
        let safePath = jxaEscape(path)
        let script = """
        ObjC.import("Foundation");
        var tags = [\(tagList)];
        var url = $.NSURL.fileURLWithPath("\(safePath)");
        url.setResourceValueForKeyError(tags, "NSURLTagNamesKey");
        "Set tags on \(safePath): " + (tags.length > 0 ? tags.join(", ") : "(cleared)");
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error setting tags: \(result.error)", true)
        }
        return (result.output, false)

    default:
        return ("Unknown tool: \(name)", true)
    }
}

// MARK: - Entry Point

@main enum FinderHelper { static func main() { MCPServer.run(name: "finder", tools: allTools(), handler: handleToolCall) } }
