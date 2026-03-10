import Testing
import Foundation
@testable import AtelierKit

@Suite("DropPathValidator")
struct DropPathValidatorTests {

    @Test("accepts file from anywhere on disk")
    func acceptsAnyFile() {
        let root = URL(fileURLWithPath: "/Users/test/project")
        let urls = [URL(fileURLWithPath: "/Users/test/Downloads/photo.png")]
        let result = DropPathValidator.validated(urls, workingDirectory: root)
        #expect(result.count == 1)
    }

    @Test("accepts file inside working directory")
    func acceptsInScope() {
        let root = URL(fileURLWithPath: "/Users/test/project")
        let urls = [URL(fileURLWithPath: "/Users/test/project/src/file.swift")]
        let result = DropPathValidator.validated(urls, workingDirectory: root)
        #expect(result.count == 1)
    }

    @Test("rejects non-file URLs")
    func rejectsNonFileURL() {
        let root = URL(fileURLWithPath: "/Users/test/project")
        let urls = [URL(string: "https://example.com/file.txt")!]
        let result = DropPathValidator.validated(urls, workingDirectory: root)
        #expect(result.isEmpty)
    }

    @Test("accepts files even without working directory")
    func acceptsWithoutWorkingDir() {
        let urls = [URL(fileURLWithPath: "/tmp/file.swift")]
        let result = DropPathValidator.validated(urls, workingDirectory: nil)
        #expect(result.count == 1)
    }

    @Test("filters mixed valid and invalid URLs")
    func filtersMixed() {
        let root = URL(fileURLWithPath: "/Users/test/project")
        let urls = [
            URL(fileURLWithPath: "/Users/test/project/a.swift"),
            URL(string: "https://example.com")!,
            URL(fileURLWithPath: "/Users/test/Desktop/c.md"),
        ]
        let result = DropPathValidator.validated(urls, workingDirectory: root)
        #expect(result.count == 2)
    }
}
