# Session Browser

> **Category:** Experience
> **Type:** New Capability · **Priority:** High
> **Milestone:** M2

---

## Problem

Every project shows one conversation — the most recent session. But real usage generates many sessions: Cmd+N for a second window, starting new conversations, old ones saved and forgotten. There's no way to see what sessions exist, switch between them, or resume an earlier thread.

Knowledge work is non-linear. You might have a research session from Tuesday, a writing session from Wednesday, and want to pick up either one. Right now, `loadMostRecent()` is the only path back in.

The infrastructure already exists: `SessionPersistence` has `list()`, `load(id:)`, and `delete(id:)`. What's missing is entirely UI.

## Solution

A session list inside the project window — not a separate view, not a sidebar. Appears when needed, stays out of the way otherwise.

- **Access:** Toolbar button or keyboard shortcut reveals the list
- **Entries:** All sessions for the current project, sorted by recency, with timestamp + preview (first user message)
- **Switch:** Save current session, load selected one, cross-fade the timeline
- **New session:** Explicit "New Conversation" action at the top
- **Delete:** Swipe or contextual menu
- **Multi-window:** Each window manages its own session independently — no conflicts

### What it doesn't do

- No renaming sessions — the preview line is enough
- No search across sessions — future Spotlight integration
- No merging or forking — each session is standalone

Should feel like switching tabs in a terminal, not navigating a file manager. The multiple-windows-same-project behavior is a feature: two windows = two sessions = two entries in the browser.

---

*Back to [Index](../../INDEX.md)*
