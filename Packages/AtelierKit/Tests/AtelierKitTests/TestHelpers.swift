import Foundation
@testable import AtelierKit
import AtelierSecurity

// MARK: - TimelineContent extraction helpers

/// Convenience accessors for extracting associated values from ``TimelineContent`` in tests.
/// Use with `try #require(item.content.userMessage)` to unwrap or fail early.
extension TimelineContent {
    var userMessage: UserMessage? {
        if case .userMessage(let msg) = self { return msg }
        return nil
    }

    var assistantMessage: AssistantMessage? {
        if case .assistantMessage(let msg) = self { return msg }
        return nil
    }

    var system: SystemEvent? {
        if case .system(let evt) = self { return evt }
        return nil
    }

    var toolUse: ToolUseEvent? {
        if case .toolUse(let evt) = self { return evt }
        return nil
    }
}

// MARK: - Mock bookmark creator

/// A no-op bookmark creator for tests that need ``ProjectStore`` or ``ProjectMigration``.
struct MockBookmarkCreator: BookmarkCreator {
    var shouldFail = false

    func createBookmarkData(for url: URL, readOnly: Bool) throws -> Data {
        if shouldFail {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "mock failure"])
        }
        return Data("mock-bookmark-\(url.path)".utf8)
    }
}
