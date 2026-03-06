import Testing
import Foundation
@testable import AtelierKit

@Suite("PlanReviewEntry")
struct PlanReviewEntryTests {

    // MARK: - Helpers

    /// Creates a Write tool event with the given file path.
    private func writeItem(id: String, filePath: String) -> TimelineItem {
        var event = ToolUseEvent(id: id, name: "Write", status: .completed)
        event.inputJSON = "{\"file_path\":\"\(filePath)\"}"
        event.cacheInputProperties()
        return TimelineItem(content: .toolUse(event))
    }

    /// Creates an ExitPlanMode tool event.
    private func exitPlanItem(id: String) -> TimelineItem {
        TimelineItem(content: .toolUse(ToolUseEvent(id: id, name: "ExitPlanMode", status: .completed)))
    }

    /// Creates an ExitPlanMode approval event.
    private func planApproval(id: String, status: ApprovalEvent.Status) -> TimelineItem {
        TimelineItem(content: .approval(ApprovalEvent(
            id: id,
            toolName: "ExitPlanMode",
            status: status,
            decidedAt: status == .pending ? nil : Date()
        )))
    }

    // MARK: - Tests

    @Test("Empty items produces empty result")
    func emptyItems() {
        let entries = PlanReviewEntry.buildList(from: [])
        #expect(entries.isEmpty)
    }

    @Test("Single cycle resolution matches input status",
          arguments: [ApprovalEvent.Status.approved, .denied, .dismissed])
    func singleCycleResolution(status: ApprovalEvent.Status) throws {
        let planPath = "/Users/dev/.claude/plans/my-plan.md"
        let items = [
            writeItem(id: "w1", filePath: planPath),
            exitPlanItem(id: "exit1"),
            planApproval(id: "approval1", status: status),
        ]

        let entries = PlanReviewEntry.buildList(from: items)

        try #require(entries.count == 1)
        #expect(entries[0].id == "exit1")
        #expect(entries[0].resolution == status)
        #expect(entries[0].filePath == planPath)
    }

    @Test("Pending approval produces pending resolution")
    func pendingApproval() throws {
        let planPath = "/Users/dev/.claude/plans/my-plan.md"
        let items = [
            writeItem(id: "w1", filePath: planPath),
            exitPlanItem(id: "exit1"),
            planApproval(id: "approval1", status: .pending),
        ]

        let entries = PlanReviewEntry.buildList(from: items)

        try #require(entries.count == 1)
        #expect(entries[0].resolution == .pending)
        #expect(entries[0].filePath == planPath)
    }

    @Test("Multiple plan review cycles tracked independently")
    func multipleCycles() throws {
        let planPath1 = "/Users/dev/.claude/plans/plan-1.md"
        let planPath2 = "/Users/dev/.claude/plans/plan-2.md"
        let items = [
            writeItem(id: "w1", filePath: planPath1),
            exitPlanItem(id: "exit1"),
            planApproval(id: "a1", status: .denied),
            // Second cycle
            writeItem(id: "w2", filePath: planPath2),
            exitPlanItem(id: "exit2"),
            planApproval(id: "a2", status: .approved),
        ]

        let entries = PlanReviewEntry.buildList(from: items)

        try #require(entries.count == 2)
        #expect(entries[0].id == "exit1")
        #expect(entries[0].resolution == .denied)
        #expect(entries[0].filePath == planPath1)
        #expect(entries[1].id == "exit2")
        #expect(entries[1].resolution == .approved)
        #expect(entries[1].filePath == planPath2)
    }

    @Test("ExitPlanMode without preceding Write produces nil filePath")
    func noPlanFile() throws {
        let items = [
            exitPlanItem(id: "exit1"),
            planApproval(id: "a1", status: .approved),
        ]

        let entries = PlanReviewEntry.buildList(from: items)

        try #require(entries.count == 1)
        #expect(entries[0].filePath == nil)
        #expect(entries[0].resolution == .approved)
    }

    @Test("Write to non-plans directory produces nil filePath")
    func wrongDirectory() throws {
        let items = [
            writeItem(id: "w1", filePath: "/Users/dev/Documents/plan.md"),
            exitPlanItem(id: "exit1"),
            planApproval(id: "a1", status: .approved),
        ]

        let entries = PlanReviewEntry.buildList(from: items)

        try #require(entries.count == 1)
        #expect(entries[0].filePath == nil)
    }

    @Test("No approval item means pending resolution")
    func noApprovalItem() throws {
        let planPath = "/Users/dev/.claude/plans/my-plan.md"
        let items = [
            writeItem(id: "w1", filePath: planPath),
            exitPlanItem(id: "exit1"),
        ]

        let entries = PlanReviewEntry.buildList(from: items)

        try #require(entries.count == 1)
        #expect(entries[0].resolution == .pending)
        #expect(entries[0].filePath == planPath)
    }

    @Test("Resolution from second cycle does not leak into first")
    func resolutionIsolation() throws {
        let items = [
            exitPlanItem(id: "exit1"),
            // No approval for first cycle
            exitPlanItem(id: "exit2"),
            planApproval(id: "a2", status: .approved),
        ]

        let entries = PlanReviewEntry.buildList(from: items)

        try #require(entries.count == 2)
        #expect(entries[0].resolution == .pending)
        #expect(entries[1].resolution == .approved)
    }
}
