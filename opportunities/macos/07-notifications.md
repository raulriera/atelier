# Rich Notifications

> **Category:** macOS Integration
> **Type:** Improvement · **Priority:** 🟡 Medium

---

## Current State (Electron / Cowork)

Basic Electron notifications — no inline actions, no grouping, no threading. Notifications are plain text with no ability to take action without switching to the app.

## Native macOS Approach

**UNUserNotificationCenter**: rich notifications with inline actions (Approve/Reject/View), thread grouping per session, critical alerts for destructive operations.

### Implementation Strategy

- **Actionable notifications:** Define `UNNotificationCategory` with custom actions:
  - Task complete: [Open Output] [View Summary]
  - Approval needed: [Approve] [View Diff] [Reject]
  - Error occurred: [Retry] [View Details] [Cancel Task]
- **Thread grouping:** Group notifications by session ID so multiple updates from the same task stack neatly.
- **Rich content:** Use `UNNotificationAttachment` to include thumbnails of generated files directly in the notification banner.
- **Critical alerts:** Destructive operations (file deletion, external API calls) use `UNNotificationSound.defaultCritical` and bypass Do Not Disturb.
- **Inline text reply:** For simple follow-up prompts, users can type a response directly in the notification without opening Atelier.

### Key Dependencies

- `UserNotifications` framework
- `UNNotificationCategory`, `UNNotificationAction`
- `UNNotificationAttachment` for rich media

---

*Back to [Index](../../INDEX.md)*
