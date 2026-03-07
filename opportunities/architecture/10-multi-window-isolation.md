# Multi-Window Session Isolation

> **Category:** Architecture
> **Type:** Bug · **Priority:** 🔴 Critical
> **Milestone:** —

---

## Problem

When multiple project windows are open, a pending approval request in one window blocks all other windows. Denying the approval in one window causes all windows to resume simultaneously. Each window should operate independently — one window waiting for user input should never affect another.

## Observed Behavior

1. Open three project windows, each with its own folder and conversation
2. Send messages in all three windows
3. When one window receives an approval request (e.g. "Edit index.html"), all windows stop making progress
4. Deny or approve the approval in that one window — all three windows resume

## Expected Behavior

Each window runs its own CLI process, approval server, and session. Approvals in window A should have zero effect on windows B and C.

## What's Already Isolated

Each `ConversationWindow` creates independent instances of:
- `CLIEngine` — spawns its own `claude -p` process
- `ApprovalServer` — unique UUID-based Unix socket (`/tmp/atelier-approval-{uuid}.sock`)
- `Session` — per-project session state
- `SessionPersistence` — per-project storage directory

The Claude CLI itself supports concurrent instances — multiple `claude` processes run fine in separate terminal tabs.

## Investigation Areas

1. **Main-actor starvation.** All streaming tasks inherit the main actor. If one task's `for try await` loop or approval handling monopolizes the main actor, other windows' tasks can't make progress. Consider whether streaming should use `Task.detached` or a custom executor.
2. **Shared CLI state.** The CLI may use a shared lock file, config directory, or API session that serializes concurrent `claude -p` processes launched from the same app bundle. Check `~/.claude/` for lock files during concurrent runs.
3. **GCD / dispatch source contention.** `ApprovalServer` uses `DispatchSource.makeReadSource` on a global queue. Verify that blocking in `handleConnection` (which awaits user decisions) doesn't starve the GCD pool for other servers.
4. **Process launch serialization.** Check if `Process.run()` or pipe setup has any app-wide serialization on macOS 26.

## Solution

TBD — root cause must be identified first. Likely candidates:

- Move streaming work off the main actor (e.g. `@ModelActor`, `Task.detached`, or a dedicated serial executor per window)
- Ensure approval server socket handling doesn't block shared GCD resources
- Add logging to identify exactly where the blocking occurs

## Dependencies

- None — this is a bug in existing architecture

---

*Back to [Index](../../INDEX.md)*
