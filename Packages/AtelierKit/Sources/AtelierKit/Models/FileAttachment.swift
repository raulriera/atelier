import Foundation
import UniformTypeIdentifiers

/// A file attached to a user message via drag-and-drop.
///
/// Attachments are displayed as thumbnails in the compose field before
/// sending, and as a scattered "paper pile" layout in the conversation
/// timeline after sending. The file path is injected into the CLI
/// message so Claude can read it.
public struct FileAttachment: Identifiable, Sendable, Codable, Hashable {
    public let id: UUID
    public let url: URL
    public let filename: String
    public let kind: Kind

    /// Broad classification used to pick the right thumbnail strategy.
    public enum Kind: String, Sendable, Codable, Hashable {
        /// Images: png, jpg, gif, webp, heic, svg, etc.
        case image
        /// PDF documents.
        case pdf
        /// Text-based documents: markdown, plain text, rich text.
        case document
        /// Source code files.
        case code
        /// Anything else.
        case other
    }

    /// Maximum number of files per drop.
    public static let maxAttachments = 5

    public init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
        self.filename = url.lastPathComponent
        self.kind = Self.classify(url)
    }

    private static func classify(_ url: URL) -> Kind {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty,
              let utType = UTType(filenameExtension: ext) else {
            return .other
        }

        if utType.conforms(to: .image) { return .image }
        if utType.conforms(to: .pdf) { return .pdf }
        if utType.conforms(to: .sourceCode) { return .code }
        if utType.conforms(to: .plainText) { return .document }

        return .other
    }
}
