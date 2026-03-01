import Foundation
import Testing
@testable import AtelierSandbox
@testable import AtelierSecurity

// MARK: - Test Audit Logger

private actor SpyAuditLogger: AuditLogger {
    private(set) var logged: [AuditEvent] = []

    func log(_ event: AuditEvent) {
        logged.append(event)
    }

    func events(
        category: AuditEvent.Category?,
        since: Date?,
        limit: Int?
    ) -> [AuditEvent] {
        logged
    }
}

@Suite("ScopedPermissionGate")
struct ScopedPermissionGateTests {

    // MARK: - Allow cases

    @Test func allowsReadInReadOnlyScope() async throws {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readOnly),
        ])
        try await gate.validate(.readFile(path: "/project/file.txt"))
    }

    @Test func allowsReadInReadWriteScope() async throws {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readWrite),
        ])
        try await gate.validate(.readFile(path: "/project/file.txt"))
    }

    @Test func allowsWriteInReadWriteScope() async throws {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readWrite),
        ])
        try await gate.validate(
            .writeFile(data: Data(), path: "/project/file.txt")
        )
    }

    @Test func allowsMoveWithinReadWriteScope() async throws {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readWrite),
        ])
        try await gate.validate(
            .moveFile(source: "/project/a.txt", destination: "/project/b.txt")
        )
    }

    @Test func allowsListDirectoryInReadOnlyScope() async throws {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readOnly),
        ])
        try await gate.validate(.listDirectory(path: "/project/subdir"))
    }

    // MARK: - Deny cases

    @Test func deniesWriteInReadOnlyScope() async {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readOnly),
        ])

        await #expect(throws: SandboxError.self) {
            try await gate.validate(
                .writeFile(data: Data(), path: "/project/file.txt")
            )
        }
    }

    @Test func deniesPathOutsideAllScopes() async {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readWrite),
        ])

        await #expect(throws: SandboxError.self) {
            try await gate.validate(.readFile(path: "/etc/passwd"))
        }
    }

    @Test func deniesWhenDestinationOutsideScope() async {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readWrite),
        ])

        await #expect(throws: SandboxError.self) {
            try await gate.validate(
                .copyFile(
                    source: "/project/file.txt",
                    destination: "/outside/file.txt"
                )
            )
        }
    }

    @Test func deniesTrashInReadOnlyScope() async {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readOnly),
        ])

        await #expect(throws: SandboxError.self) {
            try await gate.validate(.trashFile(path: "/project/file.txt"))
        }
    }

    // MARK: - Safety: prefix matching

    @Test func partialDirectoryNameDoesNotMatch() async {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/tmp/e", permission: .readWrite),
        ])

        await #expect(throws: SandboxError.self) {
            try await gate.validate(.readFile(path: "/tmp/evil/secret.txt"))
        }
    }

    @Test func mostSpecificScopeWins() async {
        let gate = ScopedPermissionGate(scopes: [
            .init(path: "/project", permission: .readWrite),
            .init(path: "/project/readonly-dir", permission: .readOnly),
        ])

        // Write to /project is allowed
        try? await gate.validate(
            .writeFile(data: Data(), path: "/project/file.txt")
        )

        // Write to the more-specific readOnly sub-scope is denied
        await #expect(throws: SandboxError.self) {
            try await gate.validate(
                .writeFile(
                    data: Data(),
                    path: "/project/readonly-dir/file.txt"
                )
            )
        }
    }

    @Test func emptyScopesDenyAll() async {
        let gate = ScopedPermissionGate(scopes: [])

        await #expect(throws: SandboxError.self) {
            try await gate.validate(.readFile(path: "/any/path"))
        }
    }

    // MARK: - Audit logging

    @Test func logsDenialWithCorrectCategory() async {
        let logger = SpyAuditLogger()
        let gate = ScopedPermissionGate(scopes: [], auditLogger: logger)

        _ = try? await gate.validate(.readFile(path: "/forbidden/file.txt"))

        let events = await logger.events(category: nil, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].category == .filePermission)
        #expect(events[0].action == "denied")
        #expect(events[0].subject == "/forbidden/file.txt")
    }

    @Test func logsApprovalWithCorrectCategory() async throws {
        let logger = SpyAuditLogger()
        let gate = ScopedPermissionGate(
            scopes: [.init(path: "/project", permission: .readOnly)],
            auditLogger: logger
        )

        try await gate.validate(.readFile(path: "/project/file.txt"))

        let events = await logger.events(category: nil, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].category == .filePermission)
        #expect(events[0].action == "approved")
        #expect(events[0].subject == "/project/file.txt")
    }
}
