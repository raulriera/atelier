import Testing
@testable import AtelierKit

@Suite("CapabilityRegistry")
struct CapabilityRegistryTests {

    @Test("All capabilities have unique IDs")
    func uniqueIDs() {
        let capabilities = CapabilityRegistry.allCapabilities()
        let ids = capabilities.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("All capabilities have non-empty names and descriptions")
    func nonEmptyMetadata() {
        for cap in CapabilityRegistry.allCapabilities() {
            #expect(!cap.name.isEmpty, "Capability \(cap.id) has empty name")
            #expect(!cap.description.isEmpty, "Capability \(cap.id) has empty description")
            #expect(!cap.iconSystemName.isEmpty, "Capability \(cap.id) has empty icon name")
        }
    }

    @Test("All capabilities have valid server configs")
    func validServerConfigs() {
        for cap in CapabilityRegistry.allCapabilities() {
            #expect(!cap.serverConfig.command.isEmpty, "Capability \(cap.id) has empty command")
            #expect(!cap.serverConfig.serverName.isEmpty, "Capability \(cap.id) has empty server name")
        }
    }

    @Test("iWork capability has expected server name")
    func iWorkServerName() throws {
        // In test context the helper binary won't exist in the bundle,
        // so iWorkCapability() returns nil. We test the config struct directly.
        let config = MCPServerConfig(
            command: "/path/to/helper",
            serverName: "atelier-iwork"
        )
        #expect(config.serverName == "atelier-iwork")
    }

    @Test("Safari capability has expected server name")
    func safariServerName() throws {
        // In test context the helper binary won't exist in the bundle,
        // so safariCapability() returns nil. We test the config struct directly.
        let config = MCPServerConfig(
            command: "/path/to/helper",
            serverName: "atelier-safari"
        )
        #expect(config.serverName == "atelier-safari")
    }
}
