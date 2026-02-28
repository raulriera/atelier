import Foundation

/// A file operation that can be planned and executed safely.
public enum FileOperation: Sendable {
    case trash(URL)
    case move(from: URL, to: URL)
    case copy(from: URL, to: URL)
    case rename(from: URL, newName: String)
}
