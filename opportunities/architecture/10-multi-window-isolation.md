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

## Remaining Investigation Areas

1. **SwiftUI view update starvation.** The standalone reproduction uses raw `Task` / `withTaskGroup`, not SwiftUI's rendering pipeline. SwiftUI may throttle or batch `@Observable` mutations. If Window A's approval card triggers high-frequency view updates, SwiftUI's rendering pass could delay Window B's event processing. Profile with Instruments (SwiftUI template) during reproduction.
2. **`@Observable` / `withAnimation` contention.** Each `handleStreamEvent` call mutates `Session` (an `@Observable`). If SwiftUI's observation tracking or animation batching serializes across windows, one window's mutations could delay another's.
3. **`Task { await server.respond(...) }` blocking main actor.** The approval response path hops to the `ApprovalServer` actor, which then does blocking `send()` on the socket. If this blocks a main-actor `Task` longer than expected, it could delay the next iteration of another window's streaming loop.
4. **Approval observer tasks.** Each window's `approvalObserverTask` and streaming task both run on the main actor. Check if `for await request in server.requests` creates contention when one AsyncStream has a pending value.

## Ruled Out

- **Claude CLI serialization.** Standalone reproduction confirmed two concurrent `claude -p --permission-prompt-tool` processes work independently from the same Swift process. One waiting 15s for approval does not block the other. Tested both off-main-actor and on-`@MainActor` consumption — no interference. The CLI is **not** the cause.
- **`FileHandle.bytes.lines` (AsyncBytes).** Standalone test confirmed two concurrent Pipe reads via `handle.bytes.lines` in the same process work independently. One blocked pipe does not stall another.
- **Main-actor starvation from stream consumption.** Reproduction with both streams consumed on `@MainActor` via `AsyncThrowingStream` + `Task.detached` producers (same architecture as `CLIEngine.send()`) showed no blocking.
- **MCP server naming.** Each window already has an isolated `ApprovalServer` with a unique UUID-based socket path. The MCP server key (`"atelier"`) is local to each CLI process's config — two processes with the same key but different sockets cannot interfere. Generating unique server names per window was tested and did not resolve the issue.
- **`Task.yield()` in streaming loop.** Adding cooperative yielding between stream events did not resolve the issue. The main-actor cooperative scheduler already yields between `for try await` iterations.
- **No CLI lock files** found in `~/.claude/`.

## Reproduction Scripts

Standalone Swift scripts in `/tmp/` confirm the CLI and Foundation layers work correctly:
- `/tmp/concurrent-pipe-test.swift` — proves `bytes.lines` is not serialized
- `/tmp/concurrent-cli-approval-test.swift` — proves two `claude -p --permission-prompt-tool` don't block each other
- `/tmp/concurrent-cli-mainactor-test.swift` — proves `@MainActor` consumption doesn't cause starvation

The bug is specific to something in the Atelier app layer, not in Foundation or the CLI.

## Dependencies

- None — this is a bug in existing architecture

---

*Back to [Index](../../INDEX.md)*
