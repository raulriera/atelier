import Foundation

/// A single suggestion prompt shown in the empty conversation state.
///
/// Each prompt pairs a visual treatment (icon, title, subtitle) with the
/// actual text that gets injected into the compose field when tapped.
public struct SuggestionPrompt: Identifiable, Sendable {
    /// Unique identifier for this suggestion.
    public let id: UUID
    /// SF Symbol name for the leading icon.
    public let iconSystemName: String
    /// Short title displayed on the chip.
    public let title: String
    /// Brief teaser describing what the prompt does.
    public let subtitle: String
    /// The full prompt text injected into the compose field.
    public let prompt: String
    /// Capability IDs that must be enabled for this prompt to appear.
    /// Empty means the prompt is always eligible (general knowledge work).
    public let requiredCapabilities: [String]

    public init(
        id: UUID = UUID(),
        iconSystemName: String,
        title: String,
        subtitle: String,
        prompt: String,
        requiredCapabilities: [String] = []
    ) {
        self.id = id
        self.iconSystemName = iconSystemName
        self.title = title
        self.subtitle = subtitle
        self.prompt = prompt
        self.requiredCapabilities = requiredCapabilities
    }
}
