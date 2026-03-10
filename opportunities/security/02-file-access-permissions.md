# File Access Permissions

> **Category:** Security & Privacy
> **Type:** Improvement · **Priority:** Critical
> **Milestone:** M1 · **Status:** 🔨 In progress

---

## Problem

The macOS App Sandbox restricts Atelier to its container by default. Users need to grant access to project folders — and that access needs to persist across launches without re-prompting.

The bookmark system restricts the app process, but the Claude CLI runs as the user's process with full access. Both need parallel controls.

## Solution

**App side:** Security-Scoped Bookmarks for persistent folder access. User picks a folder once via `NSOpenPanel`, bookmark is saved, access persists across launches.

**CLI side:** `--allowedTools` patterns scope file tools to the project directory. `--disallowedTools` blocks sensitive paths. `PreToolUse` hook validates as defense-in-depth. See `security/07-cli-filesystem-boundary.md`.

## Status

| Feature | Status |
|---------|--------|
| Security-Scoped Bookmarks (BookmarkStore) | ✅ Shipped |
| CLI path scoping via --allowedTools | ✅ Shipped |
| Sensitive path denylist | ✅ Shipped |
| PreToolUse path guard hook | ✅ Shipped |
| NSFileCoordinator for concurrent file ops | 🔲 Not started |
| Audit logging to encrypted SQLite | 🔲 Not started |

---

*Back to [Index](../../INDEX.md)*
