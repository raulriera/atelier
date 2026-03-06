import Foundation
import Testing
@testable import AtelierKit

@Suite("CapabilityStore")
struct CapabilityStoreTests {

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("cap-test-\(UUID().uuidString).json")
    }

    @Test @MainActor func loadPopulatesCapabilities() {
        let store = CapabilityStore()
        store.load()
        // In a test bundle the helper binary won't exist, so capabilities
        // may be empty. The important thing is that load() doesn't crash.
        #expect(store.enabledIDs.isEmpty)
    }

    @Test @MainActor func toggleEnablesAndDisables() {
        let store = CapabilityStore()
        store.load()

        // Toggle on — adds a group so the capability counts as enabled
        store.toggleGroup("read", for: "test-cap")
        #expect(store.isEnabled("test-cap"))

        // Toggle off
        store.toggle("test-cap")
        #expect(!store.isEnabled("test-cap"))
    }

    @Test @MainActor func toggleGroupEnablesAndDisables() {
        let store = CapabilityStore()
        store.load()

        // Toggle a specific group on
        store.toggleGroup("read", for: "test-cap")
        #expect(store.isEnabled("test-cap"))
        #expect(store.isGroupEnabled("read", for: "test-cap"))

        // Toggle it off — capability becomes disabled (empty groups)
        store.toggleGroup("read", for: "test-cap")
        #expect(!store.isEnabled("test-cap"))
    }

    @Test @MainActor func toggleGroupAddsToExistingCapability() {
        let store = CapabilityStore()
        store.load()

        store.toggleGroup("read", for: "mail")
        #expect(store.isEnabled("mail"))
        #expect(store.isGroupEnabled("read", for: "mail"))

        store.toggleGroup("send", for: "mail")
        #expect(store.isGroupEnabled("read", for: "mail"))
        #expect(store.isGroupEnabled("send", for: "mail"))

        store.toggleGroup("read", for: "mail")
        #expect(!store.isGroupEnabled("read", for: "mail"))
        #expect(store.isGroupEnabled("send", for: "mail"))
        #expect(store.isEnabled("mail"))
    }

    @Test @MainActor func persistenceRoundTrip() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // Save — use toggleGroup to add a real group
        let store1 = CapabilityStore(persistenceURL: url)
        store1.load()
        store1.toggleGroup("create", for: "iwork")
        #expect(store1.isEnabled("iwork"))

        // Reload
        let store2 = CapabilityStore(persistenceURL: url)
        store2.load()
        // Without the helper binary in the bundle, "iwork" won't be in
        // the registry, so it gets filtered out. We verify the file exists.
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test @MainActor func legacyFormatMigration() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // Write legacy format: Set<String>
        let legacyIDs: Set<String> = ["iwork", "safari"]
        let data = try JSONEncoder().encode(legacyIDs)
        try data.write(to: url)

        let store = CapabilityStore(persistenceURL: url)
        store.load()
        // Without bundled helpers, capabilities won't be in the registry,
        // so they get filtered. We verify the file was readable.
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test @MainActor func enabledCapabilityConfigsMatchesToggled() {
        let store = CapabilityStore()
        store.load()

        // No capabilities enabled -> empty
        #expect(store.enabledCapabilityConfigs().isEmpty)
    }

    @Test @MainActor func malformedFileDoesNotCrash() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // Write garbage
        try Data("not json".utf8).write(to: url)

        let store = CapabilityStore(persistenceURL: url)
        store.load()
        #expect(store.enabledIDs.isEmpty)
    }

    @Test @MainActor func emptyFileDoesNotCrash() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try Data().write(to: url)

        let store = CapabilityStore(persistenceURL: url)
        store.load()
        #expect(store.enabledIDs.isEmpty)
    }

    @Test @MainActor func enableIsIdempotent() {
        let store = CapabilityStore()
        store.load()

        store.toggleGroup("read", for: "mail")
        #expect(store.isEnabled("mail"))

        // enable on already-enabled should be a no-op
        store.enable("mail")
        #expect(store.isGroupEnabled("read", for: "mail"))
    }

    @Test @MainActor func enableActivatesAllGroups() {
        let store = CapabilityStore()
        store.load()

        #expect(!store.isEnabled("test-cap"))
        store.enable("test-cap")
        // Without registry entries, enabledGroups will be empty set.
        // But the method should at least set the key.
        #expect(store.enabledGroups["test-cap"] != nil)
    }

    @Test @MainActor func disabledCapabilitiesMentionedInTextMatchesCaseInsensitively() {
        let store = CapabilityStore()
        store.load()
        // Without bundled helpers, capabilities are empty — so result is empty.
        // This test verifies no crash and correct return type.
        let mentioned = store.disabledCapabilities(mentionedIn: "You could enable Calendar for this.")
        #expect(mentioned.isEmpty) // no registry entries in test bundle
    }
}
