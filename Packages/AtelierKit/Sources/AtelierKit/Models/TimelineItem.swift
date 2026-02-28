import Foundation

public struct TimelineItem: Identifiable, Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public var content: TimelineContent

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        content: TimelineContent
    ) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
    }
}
