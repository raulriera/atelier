# Approval & Review Flow

> **Category:** Context Control & Agent Intelligence
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Limited approval gates — the file exfiltration vulnerability demonstrated that actions can proceed without user consent. The viral 11GB file deletion incident showed that destructive operations lack adequate guardrails. There is no diff preview before file modifications, no biometric confirmation for dangerous operations, and no way to review pending actions when Atelier is in the background.

## Native macOS Approach

macOS native authorization: use **LAContext (Touch ID / password)** for destructive operations. **UserNotifications** for approval prompts even when Atelier is backgrounded. Mandatory **diff preview** before file modifications.

### Implementation Strategy

- **Tiered approval system:**
  - **Silent:** Read-only operations, file analysis, report generation → no approval needed
  - **Notify:** File creation in output folders → notification with undo option
  - **Confirm:** File modification, moves, renames → inline diff preview + confirm button
  - **Biometric:** File deletion, sending emails, modifying external systems → Touch ID / password via `LAContext`
- **Diff preview:** Before any file modification, show a native diff view (using `DifferenceKit` or custom attributed string diffing) highlighting exactly what will change. For binary files (images, PDFs), show before/after thumbnails.
- **Background approvals:** When Atelier is backgrounded, use `UNNotificationAction` with custom categories to present Approve/Reject/View actions directly in the notification. Critical actions use `UNNotificationSound.defaultCritical` to ensure visibility.
- **Audit trail:** Every approval decision (approved, rejected, timed-out) is logged to the local audit database with timestamp, action details, and approval method used.
- **Configurable per-project:** `COWORK.md` frontmatter can override approval levels:
  ```yaml
  approval:
    file_delete: biometric
    file_modify: confirm
    file_create: silent
    external_api: biometric
  ```

### User Flow: File Modification

```
Agent wants to modify ~/Reports/Q1-summary.xlsx
  │
  ├─ App shows diff preview:
  │   - Cell B12: $45,000 → $47,500
  │   - New sheet "Charts" added
  │   - Formula updated in C15
  │
  ├─ User taps "Approve" in app
  │   OR
  ├─ If app is background: notification appears
  │   "Cowork wants to modify Q1-summary.xlsx"
  │   [Approve] [View Diff] [Reject]
  │
  └─ Modification proceeds only after approval
```

### Key Dependencies

- `LocalAuthentication` framework (`LAContext`) for Touch ID
- `UserNotifications` framework with custom actions
- Diff rendering (AttributedString-based for text, Quick Look for binary)
- Audit logging to local SQLite database

---

*Back to [Index](../../INDEX.md)*
