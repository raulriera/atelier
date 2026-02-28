# Approval & Review Flow

> **Category:** Context Control & Agent Intelligence
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical
> **Milestone:** M3

---

## Problem

Limited approval gates — destructive operations can proceed without adequate guardrails. There is no diff preview before file modifications, no biometric confirmation for dangerous operations, and no way to review pending actions when the app is in the background.

## Solution

Approvals are inline in the conversation. When Claude wants to do something sensitive, an approval card appears in the timeline — showing exactly what will happen, with one-click approve or reject.

### Tiered approval system

Not everything needs the same level of scrutiny:

| Tier | Actions | User experience |
|------|---------|----------------|
| **Silent** | Read files, analyze content, generate text | Nothing. It just happens. |
| **Notify** | Create new files in the project folder | Inline note: "Created travel-plan.md" with undo |
| **Confirm** | Modify existing files, rename, move | Inline diff preview + Approve/Reject buttons |
| **Biometric** | Delete files, send emails, modify external systems | Touch ID or password via `LAContext` |

### How it looks in the conversation

```
┌─────────────────────────────────────────┐
│  Claude wants to modify                 │
│  ~/Reports/Q1-summary.xlsx              │
│                                         │
│  - Cell B12: $45,000 → $47,500          │
│  - New sheet "Charts" added             │
│  - Formula updated in C15               │
│                                         │
│  [Approve]  [View Full Diff]  [Reject]  │
└─────────────────────────────────────────┘
```

This is a timeline item — it lives in the conversation flow, not in a modal or a separate panel. You can scroll past it, come back later, or approve from a notification if the app is backgrounded.

### Background approvals

When Atelier is in the background and Claude needs approval:

- `UNNotificationAction` with Approve/Reject/View actions directly in the notification
- Critical actions use `UNNotificationSound.defaultCritical` to ensure visibility
- Tapping the notification opens the app and scrolls to the approval card

### The app learns what you trust

Over time, approval tiers adapt per project:

- If you always approve file creation silently → that tier drops to Silent for this project
- If you always review before modifying spreadsheets → that stays at Confirm
- Stored in the project context file frontmatter, editable by the user:

```yaml
approval:
  file_delete: biometric
  file_modify: confirm
  file_create: silent
  external_api: biometric
```

### Audit trail

Every approval decision (approved, rejected, timed-out) is logged:
- Timestamp, action description, tier, approval method
- Stored as JSONL in the project's `.atelier/` folder (consistent with our file-based storage model)
- Inspectable, portable, no database

## Implementation

### Phase 1 — Inline Approval Cards

- `ApprovalCard` content type in the conversation timeline (already defined in data model)
- Approve/Reject buttons that update the card's status in place
- Diff rendering for text files using `AttributedString`-based highlighting
- Quick Look integration for binary file previews (images, PDFs)

### Phase 2 — Biometric Gate

- `LAContext` for Touch ID / password confirmation on destructive operations
- `SecAccessControl` with `.biometryCurrentSet` for high-security actions
- Graceful fallback to password if biometrics unavailable

### Phase 3 — Background Notifications

- `UNNotificationAction` with custom categories for Approve/Reject/View
- Deep link from notification → specific approval card in the conversation
- Critical alert sound for destructive operations

### Phase 4 — Adaptive Tiers

- Track approval patterns per project over time
- Suggest tier adjustments: "You always approve file creation — make it silent?"
- Store overrides in context file frontmatter
- Never auto-escalate permissions — only suggest, user decides

## Dependencies

- architecture/06-conversation-model.md (ApprovalCard content type)
- experience/01-window-conversation.md (inline cards in the timeline)
- context/01-project-context-files.md (approval config in context file frontmatter)

## Notes

The approval flow is the primary trust mechanism in Atelier. It must feel fast (not interrupt flow unnecessarily) and safe (never let something destructive through without consent). The tiered system is how we balance both: most interactions are silent, most modifications show a diff, and only genuinely dangerous actions ask for biometrics.

The conversation-inline design is key. Approvals aren't modals that demand immediate attention — they're timeline items that wait for you. This means Claude can queue up multiple changes and you can review them all at once, at your pace.

---

*Back to [Index](../../INDEX.md)*
