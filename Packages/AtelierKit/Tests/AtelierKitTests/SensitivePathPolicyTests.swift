import Foundation
import Testing
@testable import AtelierKit

@Suite("SensitivePathPolicy")
struct SensitivePathPolicyTests {
    private static let home = CLIDiscovery.realHomeDirectory

    private func request(tool: String, input: [String: String]) -> ApprovalRequest {
        let json = try! JSONSerialization.data(withJSONObject: input)
        return ApprovalRequest(id: "test-1", toolName: tool, inputJSON: String(data: json, encoding: .utf8)!)
    }

    @Test("Read under ~/.ssh is denied")
    func readSshDenied() {
        let req = request(tool: "Read", input: ["file_path": "\(Self.home)/.ssh/id_rsa"])
        #expect(SensitivePathPolicy.denyReason(for: req) != nil)
    }

    @Test("Edit under Library/Keychains is denied")
    func editKeychainsDenied() {
        let req = request(tool: "Edit", input: ["file_path": "\(Self.home)/Library/Keychains/login.keychain"])
        #expect(SensitivePathPolicy.denyReason(for: req) != nil)
    }

    @Test("Write to ~/.env.production is denied")
    func writeEnvDenied() {
        let req = request(tool: "Write", input: ["file_path": "\(Self.home)/.env.production"])
        #expect(SensitivePathPolicy.denyReason(for: req) != nil)
    }

    @Test("Read of a project file is allowed")
    func readProjectFileAllowed() {
        let req = request(tool: "Read", input: ["file_path": "/Users/test/project/Sources/main.swift"])
        #expect(SensitivePathPolicy.denyReason(for: req) == nil)
    }

    @Test("WebFetch with /.ssh in URL is allowed (not a file tool)")
    func webFetchIgnored() {
        let req = request(tool: "WebFetch", input: ["url": "https://example.com/.ssh/keys"])
        #expect(SensitivePathPolicy.denyReason(for: req) == nil)
    }

    @Test("Read under ~/.aws is denied")
    func readAwsDenied() {
        let req = request(tool: "Read", input: ["file_path": "\(Self.home)/.aws/credentials"])
        #expect(SensitivePathPolicy.denyReason(for: req) != nil)
    }

    @Test("Glob under ~/.gnupg is denied")
    func globGnupgDenied() {
        let req = request(tool: "Glob", input: ["path": "\(Self.home)/.gnupg/private-keys"])
        #expect(SensitivePathPolicy.denyReason(for: req) != nil)
    }

    @Test("Read of ~/.netrc is denied")
    func readNetrcDenied() {
        let req = request(tool: "Read", input: ["file_path": "\(Self.home)/.netrc"])
        #expect(SensitivePathPolicy.denyReason(for: req) != nil)
    }

    @Test("Read of keychain-db file is denied")
    func readKeychainDbDenied() {
        let req = request(tool: "Read", input: ["file_path": "/some/path/login.keychain-db"])
        #expect(SensitivePathPolicy.denyReason(for: req) != nil)
    }

    @Test("Read under ~/.config is denied")
    func readConfigDenied() {
        let req = request(tool: "Read", input: ["file_path": "\(Self.home)/.config/some-app/secret.json"])
        #expect(SensitivePathPolicy.denyReason(for: req) != nil)
    }
}
