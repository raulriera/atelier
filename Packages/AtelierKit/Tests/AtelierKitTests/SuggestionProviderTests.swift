import Testing
@testable import AtelierKit

@Suite("SuggestionProvider")
struct SuggestionProviderTests {

    @Test("Returns exactly the requested count")
    func returnsRequestedCount() {
        let result = SuggestionProvider.suggestions(count: 4)
        #expect(result.count == 4)
    }

    @Test("Returns fewer when count exceeds pool size")
    func clampsToPoolSize() {
        // With no capabilities enabled, only general prompts are available
        let result = SuggestionProvider.suggestions(count: 100)
        #expect(result.count == SuggestionProvider.generalPrompts.count)
    }

    @Test("Returns all prompts when all capabilities enabled and count is large")
    func returnsAllWithAllCapabilities() {
        let allCapIDs = Set(SuggestionProvider.capabilityPrompts.flatMap(\.requiredCapabilities))
        let totalPool = SuggestionProvider.capabilityPrompts.count + SuggestionProvider.generalPrompts.count
        let result = SuggestionProvider.suggestions(enabledCapabilityIDs: allCapIDs, count: 100)
        #expect(result.count == totalPool)
    }

    @Test("Returns zero when count is zero")
    func returnsEmpty() {
        let result = SuggestionProvider.suggestions(count: 0)
        #expect(result.isEmpty)
    }

    @Test("Default count is 4")
    func defaultCount() {
        let result = SuggestionProvider.suggestions()
        #expect(result.count == 4)
    }

    @Test("Without capabilities, returns only general prompts")
    func noCapabilitiesReturnsGeneral() {
        let generalPrompts = Set(SuggestionProvider.generalPrompts.map(\.prompt))
        let result = SuggestionProvider.suggestions(enabledCapabilityIDs: [], count: 4)
        for suggestion in result {
            #expect(generalPrompts.contains(suggestion.prompt), "Suggestion '\(suggestion.title)' should be general")
        }
    }

    @Test("With capabilities, all slots filled by capability prompts")
    func capabilitiesArePrioritized() {
        let allCapIDs = Set(SuggestionProvider.capabilityPrompts.flatMap(\.requiredCapabilities))
        let result = SuggestionProvider.suggestions(
            enabledCapabilityIDs: allCapIDs,
            count: 4
        )
        let capabilityPrompts = Set(SuggestionProvider.capabilityPrompts.map(\.prompt))
        let capCount = result.filter { capabilityPrompts.contains($0.prompt) }.count
        #expect(capCount == 4, "All 4 slots should be capability prompts when enough are eligible")
    }

    @Test("Filters capability prompts by enabled IDs")
    func filtersCapabilityPrompts() {
        let result = SuggestionProvider.suggestions(
            enabledCapabilityIDs: ["calendar"],
            count: 20
        )
        let capabilityResults = result.filter { !$0.requiredCapabilities.isEmpty }
        #expect(!capabilityResults.isEmpty, "Should return at least one capability prompt for calendar")
        for suggestion in capabilityResults {
            #expect(
                suggestion.requiredCapabilities.allSatisfy { ["calendar"].contains($0) },
                "Suggestion '\(suggestion.title)' requires capabilities not in the enabled set"
            )
        }
    }

    @Test("All pool entries have non-empty fields")
    func poolEntriesAreComplete() {
        let allPrompts = SuggestionProvider.capabilityPrompts + SuggestionProvider.generalPrompts
        for suggestion in allPrompts {
            #expect(!suggestion.iconSystemName.isEmpty, "Suggestion '\(suggestion.title)' has empty icon")
            #expect(!suggestion.title.isEmpty, "Suggestion has empty title")
            #expect(!suggestion.subtitle.isEmpty, "Suggestion '\(suggestion.title)' has empty subtitle")
            #expect(!suggestion.prompt.isEmpty, "Suggestion '\(suggestion.title)' has empty prompt")
        }
    }

    @Test("General prompts have empty requiredCapabilities")
    func generalPromptsHaveNoRequirements() {
        for suggestion in SuggestionProvider.generalPrompts {
            #expect(suggestion.requiredCapabilities.isEmpty, "General prompt '\(suggestion.title)' should have no required capabilities")
        }
    }

    @Test("Capability prompts have non-empty requiredCapabilities")
    func capabilityPromptsHaveRequirements() {
        for suggestion in SuggestionProvider.capabilityPrompts {
            #expect(!suggestion.requiredCapabilities.isEmpty, "Capability prompt '\(suggestion.title)' should require at least one capability")
        }
    }
}
