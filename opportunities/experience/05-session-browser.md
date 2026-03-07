# Session Browser

> **Category:** Experience
> **Type:** 🆕 New Capability · **Priority:** 🟠 High
> **Milestone:** M2

---

## Problem

Every project has one visible conversation — the most recent session. But real usage generates many sessions: you Cmd+N a second window on the same project, you start a new conversation, the old one gets saved and forgotten. There's no way to see what sessions exist, switch between them, or resume an earlier thread.

This matters because knowledge work is non-linear. You might have a research session from Tuesday, a writing session from Wednesday, and want to pick up either one. Right now, `loadMostRecent()` is the only path back in.

The infrastructure already exists: `SessionPersistence` has `list()`, `load(id:)`, and `delete(id:)`. Multiple sessions per project already happen naturally (each CLI connection creates a new `sessionId`). What's missing is entirely UI.

## Solution

A session list that lives inside the project window — not a separate view, not a sidebar. It appears when you need it and stays out of the way otherwise.

### How it works

- **Access point:** A toolbar button or keyboard shortcut (Cmd+Shift+K, or similar) reveals the session list.
- **Session list:** Shows all sessions for the current project, sorted by most recent. Each entry shows a timestamp and a preview (first user message, or "New conversation").
- **Switch:** Selecting a session saves the current one and loads the selected one. The conversation timeline cross-fades.
- **New session:** Explicit "New Conversation" action at the top of the list. Saves the current session, calls `Session.reset()`, ready for a fresh CLI connection.
- **Delete:** Swipe-to-delete or contextual menu on session entries. Calls `SessionPersistence.delete(id:)`.
- **Multiple windows:** Opening the same project in two windows naturally creates two sessions. Each window manages its own session independently — no conflict because each has a unique `sessionId`. The session list shows all sessions regardless of which window created them.

### What it doesn't do

- No renaming sessions. The preview line is enough.
- No search across sessions. That's a future Spotlight integration opportunity.
- No merging or forking sessions. Each session is a standalone conversation.

## Implementation

### Phase 1 — Session metadata display

- Add a `sessionPreview` computed property to `SessionSnapshotMetadata` (first user message text, truncated)
  - This requires either: (a) storing preview text in the filename/metadata, or (b) a lightweight partial load that reads just the first user message without deserializing the full snapshot
  - Option (a) is simpler — extend `SessionSnapshotMetadata` with a `preview: String` field populated during `list()`
- Surface session count somewhere visible (toolbar subtitle, or badge)

### Phase 2 — Session list UI

- Popover or sheet triggered from toolbar, listing sessions via `SessionPersistence.list()`
- Each row: relative timestamp ("2 hours ago"), preview text, active indicator
- "New Conversation" button at top
- Delete via contextual menu

### Phase 3 — Session switching

- Save current session before loading another
- Load selected session via `SessionPersistence.load(id:)`
- Restore into `Session.restore(from:)` and update the conversation window
- Handle edge case: switching while streaming (stop generation first, or block switching)

## Dependencies

- architecture/04-session-persistence.md (the persistence layer — ✅ Done)
- experience/03-conversational-flow.md (the conversation model — 🔨 In progress)
- experience/01-window-conversation.md (the conversation window — ✅ Done)

## Notes

The session browser is the natural evolution of "projects are windows." A project isn't one conversation — it's a workspace with a history of conversations. The browser makes that history accessible without adding permanent UI weight. It should feel like switching tabs in a terminal, not like navigating a file manager.

The multiple-windows-same-project behavior is a feature, not a bug. Two windows = two sessions = two entries in the browser. No need for locks or conflict resolution.

---

*Back to [Index](../../INDEX.md)*
