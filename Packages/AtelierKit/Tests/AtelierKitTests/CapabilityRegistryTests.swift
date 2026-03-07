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

    @Test("All tool groups have unique IDs within their capability")
    func uniqueGroupIDs() {
        for cap in CapabilityRegistry.allCapabilities() {
            let groupIDs = cap.toolGroups.map(\.id)
            #expect(Set(groupIDs).count == groupIDs.count, "Duplicate group IDs in \(cap.id)")
        }
    }

    @Test("All tool groups have non-empty tools")
    func groupsHaveTools() {
        for cap in CapabilityRegistry.allCapabilities() {
            for group in cap.toolGroups {
                #expect(!group.tools.isEmpty, "Group \(group.id) in \(cap.id) has no tools")
            }
        }
    }

    @Test("Destructive tools are never auto-approved")
    func destructiveToolsRequireApproval() {
        let destructiveTools = ["finder_trash"]
        let allAutoApproved = CapabilityRegistry.allCapabilities()
            .flatMap { $0.toolGroups.flatMap(\.tools) }

        for tool in destructiveTools {
            #expect(!allAutoApproved.contains(tool), "\(tool) must not be auto-approved — it should require an approval card")
        }
    }

    @Test("Finder capability includes system prompt hint about safe deletion")
    func finderHasDeletionSafetyHint() throws {
        // Finder capability requires the helper binary in the app bundle.
        // In test bundles it may not resolve — skip gracefully.
        guard let finder = CapabilityRegistry.allCapabilities().first(where: { $0.id == "finder" }) else {
            return // Helper not in test bundle — can't validate
        }
        let hint = try #require(finder.systemPromptHint)
        #expect(hint.contains("finder_trash"))
        #expect(hint.contains("rm"))
    }

}
