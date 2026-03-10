# Rich Notifications

> **Category:** macOS Integration
> **Type:** Improvement · **Priority:** Medium
> **Milestone:** M4 · **Status:** 🔲 Not started

---

## Problem

Basic notifications with no inline actions, no grouping, no threading. Users must switch to the app for any interaction — even a simple approve/reject decision.

## Solution

**UNUserNotificationCenter** with rich, actionable notifications:

- **Inline actions** — Approve/Reject/View directly from the notification banner
- **Thread grouping** — notifications stack per session, not a flood of individual items
- **Rich content** — thumbnails of generated files attached to the notification
- **Critical alerts** — destructive operations bypass Do Not Disturb
- **Inline text reply** — respond to simple follow-up prompts without opening the app

---

*Back to [Index](../../INDEX.md)*
