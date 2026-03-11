import SwiftUI

/// Focused values for conversation-scoped menu actions.
///
/// These let the Conversation menu bar commands reach the active
/// window's conversation state (new conversation, attach files, etc.).
extension FocusedValues {
    /// Triggers a new conversation in the focused window.
    @Entry var newConversation: (() -> Void)?

    /// Toggles the file importer sheet in the focused window.
    @Entry var showAttachmentPicker: Binding<Bool>?
}
