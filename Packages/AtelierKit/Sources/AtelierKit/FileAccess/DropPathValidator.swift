import Foundation
import os

/// Validates that dropped file URLs are not in sensitive paths.
///
/// Unlike CLI tool operations (which are scoped to the project directory),
/// user-initiated drag-and-drop accepts files from anywhere on disk.
/// Only sensitive paths (credentials, keychains, etc.) are rejected.
public enum DropPathValidator {
    private static let logger = Logger(subsystem: "com.atelier.kit", category: "DropPathValidator")

    /// Returns only the URLs that pass validation: file URLs
    /// not matching sensitive path patterns.
    public static func validated(
        _ urls: [URL],
        workingDirectory: URL?
    ) -> [URL] {
        urls.filter { url in
            guard url.isFileURL else {
                logger.debug("Rejected non-file URL: \(url.absoluteString, privacy: .public)")
                return false
            }
            let path = url.standardizedFileURL.path

            // Must not match sensitive patterns
            let home = CLIDiscovery.realHomeDirectory
            for pattern in CLIEngine.sensitiveRelativePaths {
                let absolutePattern = "\(home)/\(pattern)"
                if matchesGlob(path: path, pattern: absolutePattern) {
                    logger.debug("Rejected sensitive path: \(path, privacy: .public)")
                    return false
                }
            }
            for pattern in CLIEngine.sensitiveGlobalPatterns {
                if matchesGlob(path: path, pattern: pattern) {
                    logger.debug("Rejected sensitive path: \(path, privacy: .public)")
                    return false
                }
            }

            return true
        }
    }

    private static func matchesGlob(path: String, pattern: String) -> Bool {
        // Simple glob: "foo/*" matches anything under foo/
        if pattern.hasSuffix("/*") {
            let prefix = String(pattern.dropLast(2))
            return path.hasPrefix(prefix)
        }
        // Suffix match for global patterns like "*.keychain-db"
        if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return path.hasSuffix(suffix)
        }
        return path == pattern
    }
}
