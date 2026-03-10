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
