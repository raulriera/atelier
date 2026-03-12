import Foundation

/// Strips invisible and potentially deceptive Unicode characters from text content.
///
/// These characters can be used to hide prompt injection payloads in documents:
/// zero-width spaces make text invisible to human review, and bidirectional
/// overrides can visually reorder text so it reads differently than it parses.
///
/// The sanitizer operates on raw text — it does not parse document formats
/// (PDF, docx, etc.). Format-specific stripping is a future concern.
public enum ContentSanitizer {

    /// Unicode scalar values that should be stripped from untrusted text.
    ///
    /// Categories:
    /// - Zero-width characters (U+200B–U+200F): invisible joiners, non-joiners,
    ///   and directional marks that hide content from visual inspection
    /// - Bidirectional overrides (U+202A–U+202E): can reorder displayed text
    ///   so what the user sees differs from what Claude parses
    /// - Bidirectional isolates (U+2066–U+2069): similar to overrides
    /// - Word joiner (U+2060) and zero-width no-break space (U+FEFF / BOM):
    ///   invisible characters that can break text boundaries
    /// - Tag characters (U+E0001–U+E007F): deprecated Unicode "language tag"
    ///   range that can carry hidden payloads
    static let invisibleScalars: Set<Unicode.Scalar> = {
        var set = Set<Unicode.Scalar>()
        // Zero-width and directional marks
        for v: UInt32 in 0x200B...0x200F { set.insert(Unicode.Scalar(v)!) }
        // Bidirectional overrides
        for v: UInt32 in 0x202A...0x202E { set.insert(Unicode.Scalar(v)!) }
        // Bidirectional isolates
        for v: UInt32 in 0x2066...0x2069 { set.insert(Unicode.Scalar(v)!) }
        // Word joiner
        set.insert(Unicode.Scalar(0x2060)!)
        // Zero-width no-break space (BOM)
        set.insert(Unicode.Scalar(0xFEFF)!)
        // Tag characters
        for v: UInt32 in 0xE0001...0xE007F { set.insert(Unicode.Scalar(v)!) }
        return set
    }()

    /// Strips invisible Unicode characters from the given string.
    ///
    /// Returns `nil` if the string is unchanged (no invisible characters found),
    /// avoiding unnecessary allocations.
    public static func stripInvisibleCharacters(from text: String) -> String? {
        var found = false
        for scalar in text.unicodeScalars {
            if invisibleScalars.contains(scalar) {
                found = true
                break
            }
        }
        guard found else { return nil }

        let cleaned = String(text.unicodeScalars.filter { !invisibleScalars.contains($0) })
        return cleaned
    }

    /// Sanitizes a file in place by stripping invisible Unicode characters.
    ///
    /// Only processes files that can be read as UTF-8 text. Binary files,
    /// images, and unreadable files are silently skipped.
    public static func sanitizeFileInPlace(at url: URL) {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              let cleaned = stripInvisibleCharacters(from: text) else { return }
        try? cleaned.write(to: url, atomically: true, encoding: .utf8)
    }
}
