import Foundation
import Testing
@testable import AtelierSecurity

@Suite("InMemoryAuditLogger")
struct InMemoryAuditLoggerTests {

    @Test func logsAndRetrievesEvents() async {
        let logger = InMemoryAuditLogger(capacity: 100)

        await logger.log(AuditEvent(
            category: .filePermission,
            action: "grant",
            subject: "/path/a"
        ))
        await logger.log(AuditEvent(
            category: .fileOperation,
            action: "trash",
            subject: "/path/b"
        ))

        let all = await logger.events(category: nil, since: nil, limit: nil)
        #expect(all.count == 2)
        #expect(all[0].subject == "/path/a")
        #expect(all[1].subject == "/path/b")
    }

    @Test func filtersByCategory() async {
        let logger = InMemoryAuditLogger(capacity: 100)

        await logger.log(AuditEvent(category: .filePermission, action: "grant", subject: "a"))
        await logger.log(AuditEvent(category: .fileOperation, action: "trash", subject: "b"))
        await logger.log(AuditEvent(category: .filePermission, action: "revoke", subject: "c"))

        let permissions = await logger.events(category: .filePermission, since: nil, limit: nil)
        #expect(permissions.count == 2)
        #expect(permissions[0].subject == "a")
        #expect(permissions[1].subject == "c")
    }

    @Test func filtersBySinceDate() async {
        let logger = InMemoryAuditLogger(capacity: 100)
        let cutoff = Date()

        await logger.log(AuditEvent(
            timestamp: cutoff.addingTimeInterval(-10),
            category: .fileOperation,
            action: "old",
            subject: "old"
        ))
        await logger.log(AuditEvent(
            timestamp: cutoff.addingTimeInterval(10),
            category: .fileOperation,
            action: "new",
            subject: "new"
        ))

        let recent = await logger.events(category: nil, since: cutoff, limit: nil)
        #expect(recent.count == 1)
        #expect(recent[0].subject == "new")
    }

    @Test func respectsLimit() async {
        let logger = InMemoryAuditLogger(capacity: 100)

        for i in 0..<10 {
            await logger.log(AuditEvent(category: .fileOperation, action: "action", subject: "\(i)"))
        }

        let limited = await logger.events(category: nil, since: nil, limit: 3)
        #expect(limited.count == 3)
        #expect(limited[0].subject == "0")
    }

    @Test func ringBufferEvictsOldEntries() async {
        let logger = InMemoryAuditLogger(capacity: 3)

        for i in 0..<5 {
            await logger.log(AuditEvent(category: .fileOperation, action: "action", subject: "\(i)"))
        }

        let all = await logger.events(category: nil, since: nil, limit: nil)
        #expect(all.count == 3)
        // Oldest entries (0, 1) should be evicted; remaining: 2, 3, 4
        #expect(all[0].subject == "2")
        #expect(all[1].subject == "3")
        #expect(all[2].subject == "4")
    }

    @Test func nullLoggerReturnsEmpty() {
        let logger = NullAuditLogger()
        logger.log(AuditEvent(category: .filePermission, action: "grant", subject: "x"))
        let events = logger.events(category: nil, since: nil, limit: nil)
        #expect(events.isEmpty)
    }
}
