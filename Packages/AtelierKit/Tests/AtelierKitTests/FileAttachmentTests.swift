import Testing
import Foundation
@testable import AtelierKit

@Suite("FileAttachment")
struct FileAttachmentTests {

    // MARK: - Kind Classification

    @Test("classifies PNG as image")
    func classifiesPNG() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/photo.png"))
        #expect(attachment.kind == .image)
        #expect(attachment.filename == "photo.png")
    }

    @Test("classifies HEIC as image")
    func classifiesHEIC() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/shot.heic"))
        #expect(attachment.kind == .image)
    }

    @Test("classifies JPG as image")
    func classifiesJPG() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/pic.jpg"))
        #expect(attachment.kind == .image)
    }

    @Test("classifies PDF as pdf")
    func classifiesPDF() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/doc.pdf"))
        #expect(attachment.kind == .pdf)
    }

    @Test("classifies Swift file as code")
    func classifiesSwift() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/file.swift"))
        #expect(attachment.kind == .code)
    }

    @Test("classifies Python file as code")
    func classifiesPython() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/script.py"))
        #expect(attachment.kind == .code)
    }

    @Test("classifies markdown as document")
    func classifiesMarkdown() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/readme.md"))
        #expect(attachment.kind == .document)
    }

    @Test("classifies plain text as document")
    func classifiesPlainText() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/notes.txt"))
        #expect(attachment.kind == .document)
    }

    @Test("classifies unknown extension as other")
    func classifiesUnknown() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/data.xyz123"))
        #expect(attachment.kind == .other)
    }

    @Test("classifies no extension as other")
    func classifiesNoExtension() {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/Makefile"))
        #expect(attachment.kind == .other)
    }

    // MARK: - fromImageData

    @Test("creates attachment from PNG image data")
    func fromImageDataCreatesPNG() throws {
        let pngData = createMinimalPNG()
        let attachment = try FileAttachment.fromImageData(pngData)
        #expect(attachment.kind == .image)
        #expect(attachment.filename.hasPrefix("Screenshot "))
        #expect(attachment.filename.hasSuffix(".png"))
        #expect(FileManager.default.fileExists(atPath: attachment.url.path))
        // Written data matches
        let readBack = try Data(contentsOf: attachment.url)
        #expect(readBack == pngData)
        // Cleanup
        try? FileManager.default.removeItem(at: attachment.url)
    }

    @Test("fromImageData writes to temp directory")
    func fromImageDataWritesToTemp() throws {
        let pngData = createMinimalPNG()
        let attachment = try FileAttachment.fromImageData(pngData)
        #expect(attachment.url.path.contains(FileManager.default.temporaryDirectory.path))
        try? FileManager.default.removeItem(at: attachment.url)
    }

    @Test("fromImageData generates unique files even in the same second")
    func fromImageDataUniqueNames() throws {
        let pngData = createMinimalPNG()
        let a = try FileAttachment.fromImageData(pngData)
        let b = try FileAttachment.fromImageData(pngData)
        #expect(a.id != b.id)
        #expect(a.url != b.url)
        // Both files exist independently
        #expect(FileManager.default.fileExists(atPath: a.url.path))
        #expect(FileManager.default.fileExists(atPath: b.url.path))
        try? FileManager.default.removeItem(at: a.url)
        try? FileManager.default.removeItem(at: b.url)
    }

    /// A valid 1×1 white PNG (67 bytes).
    private func createMinimalPNG() -> Data {
        Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
            0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
            0x44, 0xAE, 0x42, 0x60, 0x82,
        ])
    }

    // MARK: - Codable Round-Trip

    @Test("round-trips through JSON encoding")
    func codableRoundTrip() throws {
        let original = FileAttachment(url: URL(fileURLWithPath: "/tmp/photo.png"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FileAttachment.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.url == original.url)
        #expect(decoded.filename == original.filename)
        #expect(decoded.kind == original.kind)
    }

    // MARK: - UserMessage with Attachments

    @Test("UserMessage with empty attachments decodes from legacy JSON")
    func userMessageLegacyDecode() throws {
        // Legacy JSON without attachments field
        let json = #"{"text":"hello"}"#
        let data = json.data(using: .utf8)!
        let message = try JSONDecoder().decode(UserMessage.self, from: data)
        #expect(message.text == "hello")
        #expect(message.attachments.isEmpty)
    }

    @Test("UserMessage round-trips with attachments")
    func userMessageWithAttachments() throws {
        let attachment = FileAttachment(url: URL(fileURLWithPath: "/tmp/file.swift"))
        let original = UserMessage(text: "Check this", attachments: [attachment])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserMessage.self, from: data)
        #expect(decoded.text == original.text)
        #expect(decoded.attachments.count == 1)
        #expect(decoded.attachments.first?.kind == .code)
    }
}
