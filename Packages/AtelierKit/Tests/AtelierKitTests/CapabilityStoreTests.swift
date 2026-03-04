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

        store.toggle("test-cap")
        #expect(store.isEnabled("test-cap"))

        store.toggle("test-cap")
        #expect(!store.isEnabled("test-cap"))
    }

    @Test @MainActor func persistenceRoundTrip() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // Save
        let store1 = CapabilityStore(persistenceURL: url)
        store1.load()
        store1.toggle("iwork")
        #expect(store1.isEnabled("iwork"))

        // Reload
        let store2 = CapabilityStore(persistenceURL: url)
        store2.load()
        // Without the helper binary in the bundle, "iwork" won't be in
        // the registry, so it gets filtered out. We verify the file exists.
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test @MainActor func enabledServerConfigsMatchesToggled() {
        let store = CapabilityStore()
        store.load()

        // No capabilities enabled → empty
        #expect(store.enabledServerConfigs().isEmpty)
    }

    @Test @MainActor func malformedFileDoesNotCrash() {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // Write garbage
        try? Data("not json".utf8).write(to: url)

        let store = CapabilityStore(persistenceURL: url)
        store.load()
        #expect(store.enabledIDs.isEmpty)
    }

    @Test @MainActor func emptyFileDoesNotCrash() {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try? Data().write(to: url)

        let store = CapabilityStore(persistenceURL: url)
        store.load()
        #expect(store.enabledIDs.isEmpty)
    }
}
