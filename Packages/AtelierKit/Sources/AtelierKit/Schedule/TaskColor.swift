import Foundation

/// Preset card colors for scheduled tasks.
///
/// Each color has a name that persists in JSON and maps to a SwiftUI `Color`
/// in the view layer. The name is the source of truth — the view resolves it.
public enum TaskColor: String, CaseIterable, Sendable, Identifiable {
    case blue, purple, pink, red, orange, green, teal, indigo, brown, gray

    public var id: String { rawValue }

    /// The default color name assigned to new tasks.
    public static let defaultName: String = TaskColor.blue.rawValue
}
