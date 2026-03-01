/// The level of file access granted via a security-scoped bookmark.
public enum FilePermission: String, Sendable, Codable {
    case readOnly
    case readWrite
}
