import Foundation

/// Identifies the type of a file based on its extension.
///
/// Used by the view layer to pick the appropriate renderer —
/// formatted document, syntax-highlighted code, structured data, etc.
public enum FileType: Sendable, Hashable {
    case markdown
    case code(language: String)
    case data(format: String)
    case plainText
    case unknown

    /// Determines the file type from a file name or path.
    public init(fileName: String) {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else {
            self = .plainText
            return
        }

        if let type = Self.extensionMap[ext] {
            self = type
        } else {
            self = .unknown
        }
    }

    private static let extensionMap: [String: FileType] = {
        var map = [String: FileType]()

        // Markdown
        for ext in ["md", "markdown", "mdown", "mkd"] {
            map[ext] = .markdown
        }

        // Code
        let languages: [(String, [String])] = [
            ("swift", ["swift"]),
            ("python", ["py", "pyw"]),
            ("javascript", ["js", "mjs", "cjs"]),
            ("typescript", ["ts", "mts", "cts"]),
            ("ruby", ["rb"]),
            ("rust", ["rs"]),
            ("go", ["go"]),
            ("java", ["java"]),
            ("kotlin", ["kt", "kts"]),
            ("c", ["c", "h"]),
            ("cpp", ["cpp", "cc", "cxx", "hpp"]),
            ("csharp", ["cs"]),
            ("html", ["html", "htm"]),
            ("css", ["css"]),
            ("scss", ["scss", "sass"]),
            ("shell", ["sh", "bash", "zsh", "fish"]),
            ("sql", ["sql"]),
            ("yaml", ["yml", "yaml"]),
            ("toml", ["toml"]),
            ("xml", ["xml", "plist"]),
            ("dockerfile", ["dockerfile"]),
        ]
        for (language, exts) in languages {
            for ext in exts {
                map[ext] = .code(language: language)
            }
        }

        // Structured data
        for (format, exts) in [("json", ["json", "geojson"]), ("csv", ["csv", "tsv"])] {
            for ext in exts {
                map[ext] = .data(format: format)
            }
        }

        // Plain text
        for ext in ["txt", "text", "log", "rtf"] {
            map[ext] = .plainText
        }

        return map
    }()
}
