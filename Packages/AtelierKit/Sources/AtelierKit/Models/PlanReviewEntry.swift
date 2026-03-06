/// A single plan review entry, pairing an ExitPlanMode tool event with its
/// file path and approval resolution.
public struct PlanReviewEntry: Sendable, Identifiable {
    /// The ExitPlanMode tool event ID.
    public let id: String
    /// The resolution status — `.pending` until the user decides.
    public var resolution: ApprovalEvent.Status
    /// Path to the plan file on disk (`~/.claude/plans/*.md`), if found.
    public var filePath: String?

    public init(id: String, resolution: ApprovalEvent.Status = .pending, filePath: String? = nil) {
        self.id = id
        self.resolution = resolution
        self.filePath = filePath
    }
}

// MARK: - Building from timeline items

extension PlanReviewEntry {
    /// Builds plan review entries from a list of timeline items.
    ///
    /// Pure function — scans items to pair each ExitPlanMode tool event with:
    /// - The preceding Write to `~/.claude/plans/` (file path)
    /// - The following ExitPlanMode approval (resolution)
    ///
    /// Forward scan for resolution stops at the next plan cycle to isolate
    /// multiple reviews.
    public static func buildList(from items: [TimelineItem]) -> [PlanReviewEntry] {
        // First pass: collect ExitPlanMode tool event indices.
        var planIndices: [(index: Int, id: String)] = []
        for (i, item) in items.enumerated() {
            if case .toolUse(let event) = item.content, event.isPlanReview {
                planIndices.append((i, event.id))
            }
        }
        guard !planIndices.isEmpty else { return [] }

        var entries: [PlanReviewEntry] = []

        for (offset, plan) in planIndices.enumerated() {
            // Backward scan for file path
            let filePath = findPlanFilePath(in: items, before: plan.index)

            // Forward scan for resolution — stop at the next plan cycle
            let upperBound = offset + 1 < planIndices.count ? planIndices[offset + 1].index : items.count
            let resolution = findResolution(in: items, after: plan.index, upperBound: upperBound)

            entries.append(PlanReviewEntry(id: plan.id, resolution: resolution, filePath: filePath))
        }

        return entries
    }

    /// Scans backward from `beforeIndex` for a Write to `~/.claude/plans/`.
    private static func findPlanFilePath(in items: [TimelineItem], before beforeIndex: Int) -> String? {
        for index in items[..<beforeIndex].indices.reversed() {
            guard case .toolUse(let event) = items[index].content,
                  event.name == "Write",
                  let path = event.filePath,
                  path.contains(".claude/plans/") else { continue }
            return path
        }
        return nil
    }

    /// Scans forward from `afterIndex` for a resolved ExitPlanMode approval.
    private static func findResolution(
        in items: [TimelineItem],
        after afterIndex: Int,
        upperBound: Int
    ) -> ApprovalEvent.Status {
        let searchRange = (afterIndex + 1)..<min(upperBound, items.count)
        for index in searchRange {
            if case .approval(let event) = items[index].content,
               event.toolName == "ExitPlanMode",
               event.status != .pending {
                return event.status
            }
        }
        return .pending
    }
}
