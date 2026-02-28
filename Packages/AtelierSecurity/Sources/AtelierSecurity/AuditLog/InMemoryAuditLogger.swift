import Foundation

/// Thread-safe in-memory audit logger backed by a ring buffer.
public actor InMemoryAuditLogger: AuditLogger {
    private var buffer: [AuditEvent]
    private let capacity: Int
    private var head: Int = 0
    private var count: Int = 0

    public init(capacity: Int = 1000) {
        precondition(capacity > 0, "Capacity must be positive")
        self.capacity = capacity
        self.buffer = Array(repeating: AuditEvent(category: .fileOperation, action: "", subject: ""), count: capacity)
    }

    public func log(_ event: AuditEvent) {
        buffer[head] = event
        head = (head + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    public func events(
        category: AuditEvent.Category? = nil,
        since: Date? = nil,
        limit: Int? = nil
    ) -> [AuditEvent] {
        let all = orderedEvents()

        let filtered = all.filter { event in
            if let category, event.category != category { return false }
            if let since, event.timestamp < since { return false }
            return true
        }

        if let limit {
            return Array(filtered.prefix(limit))
        }
        return filtered
    }

    /// Returns all stored events in insertion order (oldest first).
    private func orderedEvents() -> [AuditEvent] {
        if count < capacity {
            return Array(buffer[0..<count])
        }
        return Array(buffer[head..<capacity]) + Array(buffer[0..<head])
    }
}
