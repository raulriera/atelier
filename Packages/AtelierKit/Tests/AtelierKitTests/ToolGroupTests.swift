import Foundation
import Testing
@testable import AtelierKit

@Suite("ToolGroup")
struct ToolGroupTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let group = ToolGroup(
            id: "read",
            name: "Read",
            description: "Search and read messages",
            tools: ["mail_search", "mail_get"]
        )
        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(ToolGroup.self, from: data)
        #expect(decoded == group)
    }

    @Test("Empty tools array encodes correctly")
    func emptyToolsRoundTrip() throws {
        let group = ToolGroup(id: "empty", name: "Empty", description: "No tools", tools: [])
        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(ToolGroup.self, from: data)
        #expect(decoded == group)
        #expect(decoded.tools.isEmpty)
    }
}
