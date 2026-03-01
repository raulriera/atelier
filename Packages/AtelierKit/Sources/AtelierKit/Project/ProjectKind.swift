import Foundation

/// Detected type of a project folder based on its contents.
public enum ProjectKind: String, Sendable, Codable, CaseIterable {
    case code
    case writing
    case research
    case mixed
    case unknown
}
