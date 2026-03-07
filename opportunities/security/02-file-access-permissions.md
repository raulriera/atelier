# File Access Permissions

> **Category:** Security & Privacy
> **Type:** Improvement · **Priority:** 🔴 Critical
> **Milestone:** M1

---

## Current State (Electron / Cowork)

Folder-scoped access via VirtioFS mount — but no per-file granularity or audit trail. Once a user grants access to a folder, the agent has read/write access to everything inside it with no logging of individual file operations.

## Native macOS Approach

macOS **App Sandbox** with **Security-Scoped Bookmarks** for persistent folder access. `NSFileCoordinator` for safe concurrent access. Full audit log of every file read/write/delete with timestamps.

### Implementation Strategy

- **Security-Scoped Bookmarks:** When users grant folder access via `NSOpenPanel`, create Security-Scoped Bookmarks that persist across app launches. Users grant access once and it's remembered, but revocable at any time.
- **Per-file audit log:** Every file operation (read, write, create, delete, move, rename) is logged to a local encrypted SQLite database with: timestamp, file path, operation type, session ID, and whether the operation was user-approved.
- **NSFileCoordinator:** Wrap all file operations in `NSFileCoordinator` to safely handle concurrent access from Finder, Time Machine, and other apps.
- **Read-only mode:** For analysis tasks, mount folders as read-only in the VM. The agent can read files but cannot modify them without explicit mode escalation.
- **Access revocation:** A settings panel shows all granted folder accesses with one-click revocation. Revoking access immediately invalidates the Security-Scoped Bookmark and unmounts the folder from the VM.

### Gap: bookmarks don't restrict the CLI

Security-scoped bookmarks restrict the **app process** (`Atelier.app`). The Claude Code CLI is a separate binary (`~/.local/bin/claude`) that runs as the user's process — outside the app sandbox, with full filesystem access. The bookmark system has no effect on what the CLI can read or write.

This means there are two parallel access control systems that don't talk to each other:
1. **App-level:** Bookmarks restrict Atelier.app to user-granted folders (works correctly)
2. **CLI-level:** No restrictions whatsoever (the gap)

The granted folder list from bookmarks must be projected onto the CLI via `--allowedTools` path patterns and `PreToolUse` hooks. See `security/07-cli-filesystem-boundary.md` for the full solution.

### Key Dependencies

- App Sandbox entitlements
- `NSURL` Security-Scoped Bookmarks
- `NSFileCoordinator` and `NSFilePresenter`
- SQLite audit database with encryption
- security/07-cli-filesystem-boundary.md (projecting bookmark grants onto CLI flags)

---

*Back to [Index](../../INDEX.md)*
