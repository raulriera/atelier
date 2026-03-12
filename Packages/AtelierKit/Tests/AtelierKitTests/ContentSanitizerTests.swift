import Foundation
import Testing
@testable import AtelierKit

@Suite("ContentSanitizer")
struct ContentSanitizerTests {

    /// A single invisible character case: the scalar to inject and a human-readable label.
    struct InvisibleChar: CustomTestStringConvertible, Sendable {
        let scalar: Unicode.Scalar
        let label: String
        var testDescription: String { label }
    }

    static let invisibleChars: [InvisibleChar] = [
        InvisibleChar(scalar: "\u{200B}", label: "zero-width space"),
        InvisibleChar(scalar: "\u{200C}", label: "zero-width non-joiner"),
        InvisibleChar(scalar: "\u{200D}", label: "zero-width joiner"),
        InvisibleChar(scalar: "\u{200E}", label: "left-to-right mark"),
        InvisibleChar(scalar: "\u{202A}", label: "LR embedding"),
        InvisibleChar(scalar: "\u{202E}", label: "RL override"),
        InvisibleChar(scalar: "\u{2066}", label: "LR isolate"),
        InvisibleChar(scalar: "\u{2069}", label: "pop directional isolate"),
        InvisibleChar(scalar: "\u{2060}", label: "word joiner"),
        InvisibleChar(scalar: "\u{FEFF}", label: "byte order mark"),
        InvisibleChar(scalar: "\u{E0001}", label: "language tag"),
        InvisibleChar(scalar: "\u{E0041}", label: "tag latin A"),
    ]

    // MARK: - Invisible character stripping

    @Test("Strips invisible character", arguments: invisibleChars)
    func stripsInvisibleCharacter(char: InvisibleChar) {
        let input = "foo\(char.scalar)bar"
        let result = ContentSanitizer.stripInvisibleCharacters(from: input)
        #expect(result == "foobar")
    }

    @Test func stripsMultipleInvisibleCharacterTypes() {
        let input = "\u{FEFF}Hello\u{200B} \u{202E}World\u{200C}\u{2066}!"
        let result = ContentSanitizer.stripInvisibleCharacters(from: input)
        #expect(result == "Hello World!")
    }

    // MARK: - Clean text passthrough

    @Test func returnsNilForCleanText() {
        let input = "Just a normal string with no invisible characters."
        #expect(ContentSanitizer.stripInvisibleCharacters(from: input) == nil)
    }

    @Test func returnsNilForEmptyString() {
        #expect(ContentSanitizer.stripInvisibleCharacters(from: "") == nil)
    }

    @Test func preservesRegularUnicode() {
        #expect(ContentSanitizer.stripInvisibleCharacters(from: "Héllo Wörld 日本語 🎉") == nil)
    }

    @Test func preservesNewlinesAndTabs() {
        #expect(ContentSanitizer.stripInvisibleCharacters(from: "line one\nline two\ttabbed") == nil)
    }

    // MARK: - File sanitization

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sanitizer-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func sanitizesFileInPlace() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test.txt")
        try "Hello\u{200B}World\u{202E}!".write(to: fileURL, atomically: true, encoding: .utf8)

        ContentSanitizer.sanitizeFileInPlace(at: fileURL)

        let result = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(result == "HelloWorld!")
    }

    @Test func skipsCleanFile() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("clean.txt")
        try "Nothing to strip here.".write(to: fileURL, atomically: true, encoding: .utf8)

        let modBefore = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
        ContentSanitizer.sanitizeFileInPlace(at: fileURL)
        let modAfter = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date

        #expect(modBefore == modAfter, "Clean file should not be rewritten")
    }

    @Test func skipsBinaryFile() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("binary.dat")
        let binaryData = Data([0x00, 0xFF, 0x80, 0x7F, 0xFE, 0xED])
        try binaryData.write(to: fileURL)

        ContentSanitizer.sanitizeFileInPlace(at: fileURL)

        let result = try Data(contentsOf: fileURL)
        #expect(result == binaryData, "Binary file should be left unchanged")
    }

    @Test func skipsNonexistentFile() {
        let fakeURL = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).txt")
        ContentSanitizer.sanitizeFileInPlace(at: fakeURL)
    }
}
